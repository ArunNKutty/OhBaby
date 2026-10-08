#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/app"

flutter pub get
dart run build_runner build --delete-conflicting-outputs

exec flutter run -d web-server --release \
  --web-hostname 0.0.0.0 \
  --web-port 47219 \
  --no-web-resources-cdn \
  --dart-define=API_BASE="${API_BASE:-http://127.0.0.1:47220}"
