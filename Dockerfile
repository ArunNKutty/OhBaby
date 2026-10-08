# Flutter web bundle, then the Go API. DuckDB is linked into the API binary.
# docker compose up builds both images and keeps the database on the ohbaby-data volume.

FROM debian:bookworm-slim AS web-build
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /tmp/flutter.tar.xz \
        https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.6-stable.tar.xz \
    && tar -C /opt -xf /tmp/flutter.tar.xz \
    && rm /tmp/flutter.tar.xz
ENV PATH="/opt/flutter/bin:${PATH}"
RUN git config --global --add safe.directory /opt/flutter \
    && flutter config --no-analytics --enable-web \
    && flutter precache --web
WORKDIR /src
COPY app /src
RUN flutter pub get \
    && dart run build_runner build --delete-conflicting-outputs \
    && flutter build web --release --no-web-resources-cdn --dart-define=API_BASE=

FROM nginx:1.27-alpine AS web
COPY deploy/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=web-build /src/build/web /usr/share/nginx/html
EXPOSE 80

FROM golang:1.27-bookworm AS api-build
RUN apt-get update && apt-get install -y --no-install-recommends gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY server /src
RUN CGO_ENABLED=1 go build -o /out/ohbaby ./cmd/api

FROM debian:bookworm-slim AS api
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl libstdc++6 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=api-build /out/ohbaby /usr/local/bin/ohbaby
ENV OHBABY_ADDR=:47220
ENV OHBABY_DB=/data/ohbaby.duckdb
EXPOSE 47220
VOLUME ["/data"]
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=5 \
    CMD curl -fsS http://127.0.0.1:47220/healthz || exit 1
CMD ["ohbaby"]
