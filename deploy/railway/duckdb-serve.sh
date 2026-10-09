#!/bin/sh
# Runs the official /duckdb binary. quack_serve returns, and the CLI exits
# unless stdin stays open, so a never-ending pipe keeps the server process up.
set -eu

token="${DUCKDB_QUACK_TOKEN:-}"
case "$token" in
  ""|dev-only-not-for-production)
    echo "Set DUCKDB_QUACK_TOKEN to a private 4-128 character token before deploying." >&2
    exit 1
    ;;
  *[!A-Za-z0-9._-]*)
    echo "DUCKDB_QUACK_TOKEN may contain only letters, numbers, dots, and dashes." >&2
    exit 1
    ;;
esac
if [ "${#token}" -lt 4 ] || [ "${#token}" -gt 128 ]; then
  echo "DUCKDB_QUACK_TOKEN must be 4 to 128 characters." >&2
  exit 1
fi

export HOME="${HOME:-/workspace}"
mkdir -p "$HOME"
db="${DUCKDB_PATH:-/workspace/ohbaby.duckdb}"

tail -f /dev/null | /duckdb -unsigned -interactive -cmd \
  "LOAD '/opt/httpfs.duckdb_extension'; LOAD '/opt/quack.duckdb_extension'; CALL quack_serve('quack:0.0.0.0:9494', token := '${token}', allow_other_hostname => true);" \
  "$db"
