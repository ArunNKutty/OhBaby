# Official DuckDB CLI from duckdb/duckdb, plus a shell that keeps stdin open.
# Railway does not keep a container stdin open, and the CLI exits after quack_serve returns.
FROM duckdb/duckdb AS cli

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates gzip \
    && rm -rf /var/lib/apt/lists/*
COPY --from=cli /duckdb /duckdb
COPY deploy/duckdb/httpfs.duckdb_extension.gz /tmp/httpfs.duckdb_extension.gz
COPY deploy/duckdb/quack.duckdb_extension.gz /tmp/quack.duckdb_extension.gz
RUN gzip -dc /tmp/httpfs.duckdb_extension.gz > /opt/httpfs.duckdb_extension \
    && gzip -dc /tmp/quack.duckdb_extension.gz > /opt/quack.duckdb_extension \
    && rm /tmp/httpfs.duckdb_extension.gz /tmp/quack.duckdb_extension.gz
COPY deploy/railway/duckdb-serve.sh /usr/local/bin/duckdb-serve
RUN chmod +x /usr/local/bin/duckdb-serve
ENV HOME=/workspace
WORKDIR /workspace
EXPOSE 9494
ENTRYPOINT ["/usr/local/bin/duckdb-serve"]
