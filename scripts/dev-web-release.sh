#!/usr/bin/env bash
# Fast local web: release build + Go serves UI and API on one port (gzip + cache headers).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/app"

flutter pub get
dart run build_runner build --delete-conflicting-outputs

flutter build web --release --no-web-resources-cdn --dart-define=API_BASE=

export OHBABY_ADDR="${OHBABY_ADDR:-:47219}"
export OHBABY_WEB_ROOT="$ROOT/app/build/web"
export OHBABY_DB="${OHBABY_DB:-$ROOT/data/ohbaby.duckdb}"
export GOOGLE_REDIRECT_URI="${GOOGLE_REDIRECT_URI:-http://127.0.0.1:47219/v1/auth/google/callback}"
export OHBABY_APP_ORIGINS="${OHBABY_APP_ORIGINS:-http://127.0.0.1:47219,http://localhost:47219}"
export OHBABY_ALLOWED_ORIGINS="${OHBABY_ALLOWED_ORIGINS:-$OHBABY_APP_ORIGINS}"

cd "$ROOT/server"
export CGO_ENABLED=1
exec go run ./cmd/api
