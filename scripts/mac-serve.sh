#!/usr/bin/env bash
# Build the Flutter web app and serve it with the Go API on one port.
# Point cloudflared at that port. See the README.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if ! command -v flutter >/dev/null || ! command -v go >/dev/null; then
  echo "Install Flutter 3.47 (stable) and Go 1.27, then run this again." >&2
  exit 1
fi

(
  cd app
  flutter build web --release --no-web-resources-cdn --dart-define=API_BASE=
)

export OHBABY_ADDR="${OHBABY_ADDR:-:47221}"
export OHBABY_WEB_ROOT="$root/app/build/web"
export OHBABY_DB="${OHBABY_DB:-$root/data/ohbaby.duckdb}"
export OHBABY_APP_ORIGINS="${OHBABY_APP_ORIGINS:-http://127.0.0.1:47221,http://localhost:47221}"
export OHBABY_ALLOWED_ORIGINS="${OHBABY_ALLOWED_ORIGINS:-$OHBABY_APP_ORIGINS}"

cd "$root/server"
export CGO_ENABLED=1
exec go run ./cmd/api
