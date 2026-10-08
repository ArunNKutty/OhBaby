FROM python:3.12-slim-bookworm
RUN pip install --no-cache-dir duckdb==1.5.6
WORKDIR /srv
COPY serve.py /srv/serve.py
COPY quack.duckdb_extension.gz /tmp/quack.duckdb_extension.gz
COPY httpfs.duckdb_extension.gz /tmp/httpfs.duckdb_extension.gz
RUN python -c "import gzip,shutil; \
shutil.copyfileobj(gzip.open('/tmp/quack.duckdb_extension.gz','rb'), open('/opt/quack.duckdb_extension','wb')); \
shutil.copyfileobj(gzip.open('/tmp/httpfs.duckdb_extension.gz','rb'), open('/opt/httpfs.duckdb_extension','wb'))"
ENV HOME=/data
ENV DUCKDB_PATH=/data/ohbaby.duckdb
EXPOSE 9494
VOLUME ["/data"]
HEALTHCHECK --interval=5s --timeout=3s --start-period=40s --retries=20 \
    CMD python -c "import socket; socket.create_connection(('127.0.0.1',9494),2).close()"
CMD ["python", "-u", "/srv/serve.py"]
