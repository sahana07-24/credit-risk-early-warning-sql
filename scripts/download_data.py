"""Rebuild data/raw/*.parquet from the original Berka .asc files.

Usage: python scripts/download_data.py
Downloads the public dataset from GitHub (jlacko/berka-dataset) and converts each table to parquet,
keeping every column as text exactly as published. All decoding happens later, in sql/01_staging.sql.
"""
import tempfile
import urllib.request
from pathlib import Path

import duckdb

BASE = "https://raw.githubusercontent.com/jlacko/berka-dataset/master/"
TABLES = ["account", "card", "client", "disp", "district", "loan", "order", "trans"]
OUT = Path(__file__).resolve().parent.parent / "data" / "raw"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    with tempfile.TemporaryDirectory() as tmp:
        for table in TABLES:
            src = Path(tmp) / f"{table}.asc"
            print(f"Downloading {table}.asc ...")
            urllib.request.urlretrieve(BASE + f"{table}.asc", src)
            con.execute(
                f"COPY (SELECT * FROM read_csv('{src.as_posix()}', delim=';', header=true, quote='\"', "
                f"all_varchar=true, nullstr=['', '?'])) TO '{(OUT / f'{table}.parquet').as_posix()}' "
                f"(FORMAT parquet, COMPRESSION zstd)"
            )
    print(f"Saved {len(TABLES)} tables to {OUT}")


if __name__ == "__main__":
    main()
