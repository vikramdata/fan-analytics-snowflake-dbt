"""Upload data/raw/*.csv to the Snowflake landing stage and run snowflake/02_load_raw.sql.

Requires: pip install snowflake-connector-python
Env vars: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD
Run 01_setup.sql once in Snowsight (as ACCOUNTADMIN) before this.
"""
import os
from pathlib import Path

import snowflake.connector

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"


def main():
    con = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"], user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"], role="LOADER",
        warehouse="TRANSFORM_WH", database="FAN_ANALYTICS", schema="RAW")
    cur = con.cursor()

    # Drop comment lines, split into statements; setup runs before the PUTs, loads after.
    sql = (ROOT / "snowflake" / "02_load_raw.sql").read_text()
    body = "\n".join(l for l in sql.splitlines() if not l.strip().startswith("--"))
    statements = [s.strip() for s in body.split(";") if s.strip()]
    is_load = lambda s: s.lower().startswith(("truncate", "copy", "select"))
    setup = [s for s in statements if not is_load(s)]
    load = [s for s in statements if is_load(s)]

    for s in setup:
        cur.execute(s)
    for csv in sorted(RAW.glob("*.csv")):
        print(f"PUT {csv.name}")
        cur.execute(f"put 'file://{csv.as_posix()}' @landing_stage auto_compress=true overwrite=true")
    for s in load:
        cur.execute(s)
    for row in cur.fetchall():
        print(row)
    con.close()


if __name__ == "__main__":
    main()
