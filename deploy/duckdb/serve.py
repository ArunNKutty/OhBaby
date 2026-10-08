"""Keep a DuckDB file open and serve it to other DuckDB clients over Quack."""

import os
import re
import sys
import time

import duckdb

_TOKEN = re.compile(r"^[A-Za-z0-9._-]{4,128}$")


def main() -> None:
    token = os.environ.get("DUCKDB_QUACK_TOKEN", "")
    if not _TOKEN.match(token):
        sys.exit("DUCKDB_QUACK_TOKEN must be 4-128 letters, numbers, dots, or dashes")
    path = os.environ.get("DUCKDB_PATH", "/data/ohbaby.duckdb")
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    con = duckdb.connect(path)
    con.execute("INSTALL '/opt/httpfs.duckdb_extension'")
    con.execute("LOAD httpfs")
    con.execute("INSTALL '/opt/quack.duckdb_extension'")
    con.execute("LOAD quack")
    con.execute(
        f"CALL quack_serve('quack:0.0.0.0:9494', token = '{token}', allow_other_hostname => true)"
    )
    print("DuckDB Quack server listening on 0.0.0.0:9494", flush=True)
    while True:
        time.sleep(3600)


if __name__ == "__main__":
    main()
