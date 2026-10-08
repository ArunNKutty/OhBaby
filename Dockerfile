# Builds the Go API. The Flutter web bundle is produced first:
#   (cd app && flutter build web --release --no-web-resources-cdn --dart-define=API_BASE=)
# DuckDB's Go driver needs cgo. One process is the only writer of the database file.
FROM golang:1.27-bookworm AS build
RUN apt-get update && apt-get install -y --no-install-recommends gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY server/ ./
RUN CGO_ENABLED=1 go build -o /out/ohbaby ./cmd/api

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /out/ohbaby /usr/local/bin/ohbaby
COPY app/build/web /srv/web
ENV OHBABY_ADDR=:47221
ENV OHBABY_WEB_ROOT=/srv/web
ENV OHBABY_DB=/data/ohbaby.duckdb
# Firebase web config is read from the environment at runtime. Leave it unset to run without sign-in.
EXPOSE 47221
VOLUME ["/data"]
CMD ["ohbaby"]
