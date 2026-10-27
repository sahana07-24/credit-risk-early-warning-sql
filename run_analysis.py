"""Load the raw Berka tables, run every SQL file in sql/ in order, and save each result to outputs/.

Usage:
    pip install -r requirements.txt
    python run_analysis.py        # runs the SQL, then draws the charts in charts/
"""
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).parent
RAW_DIR = ROOT / "data" / "raw"
SQL_DIR = ROOT / "sql"
OUT_DIR = ROOT / "outputs"
DB_PATH = ROOT / "bank.duckdb"


def load_raw(con: duckdb.DuckDBPyConnection) -> None:
    """Load each raw table exactly as published (all text), named raw_<table>."""
    for parquet in sorted(RAW_DIR.glob("*.parquet")):
        con.execute(f"CREATE OR REPLACE TABLE raw_{parquet.stem} AS SELECT * FROM read_parquet('{parquet.as_posix()}')")


def run_sql(con: duckdb.DuckDBPyConnection) -> None:
    OUT_DIR.mkdir(exist_ok=True)
    for sql_file in sorted(SQL_DIR.glob("*.sql")):
        df = con.sql(sql_file.read_text()).df()  # runs every statement in the file, returns the last SELECT
        df.to_csv(OUT_DIR / f"{sql_file.stem}.csv", index=False)
        print(f"\n=== {sql_file.name}  ({len(df)} rows) ===")
        print(df.head(15).to_string(index=False))

    # Loan-level table for Power BI / further modelling
    con.sql("SELECT * FROM loan_scores").df().to_csv(OUT_DIR / "loan_level_features.csv", index=False)


if __name__ == "__main__":
    with duckdb.connect(str(DB_PATH)) as con:
        load_raw(con)
        run_sql(con)

    sys.path.insert(0, str(ROOT))
    import make_charts

    make_charts.main()
