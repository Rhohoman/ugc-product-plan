"""Load a top-products CSV export (e.g. Kalodata / FastMoss) into Postgres.

Usage:
    python -m ugc.ingest.load_csv path/to/export.csv --source kalodata

Edit COLUMN_MAP to match the column headers of whichever tool you export from.
"""
import argparse
import json
import os
from datetime import datetime, timezone

import pandas as pd
import psycopg

# CSV header -> our column name. Adjust per tool.
COLUMN_MAP = {
    "Product ID": "product_id",
    "Product Name": "title",
    "Category": "category",
    "Shop": "shop_name",
    "Price": "price",
    "Units Sold (7d)": "est_units_sold_7d",
    "Units Sold (30d)": "est_units_sold_30d",
    "GMV (30d)": "est_gmv_30d",
    "Commission Rate": "affiliate_commission_pct",
    "Creators": "creator_count",
    "Videos": "video_count",
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--source", required=True)
    args = ap.parse_args()

    df = pd.read_csv(args.csv).rename(columns=COLUMN_MAP)
    captured_at = datetime.now(timezone.utc)

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn, conn.cursor() as cur:
        for rank, row in enumerate(df.to_dict("records"), start=1):
            cur.execute(
                """insert into product (product_id, title, category, shop_name)
                   values (%s, %s, %s, %s)
                   on conflict (product_id) do update set title = excluded.title""",
                (str(row["product_id"]), row.get("title"), row.get("category"), row.get("shop_name")),
            )
            cur.execute(
                """insert into product_snapshot
                   (product_id, captured_at, source, sales_rank, price, est_units_sold_7d,
                    est_units_sold_30d, est_gmv_30d, affiliate_commission_pct,
                    creator_count, video_count, raw)
                   values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                   on conflict do nothing""",
                (
                    str(row["product_id"]), captured_at, args.source, rank,
                    row.get("price"), row.get("est_units_sold_7d"), row.get("est_units_sold_30d"),
                    row.get("est_gmv_30d"), row.get("affiliate_commission_pct"),
                    row.get("creator_count"), row.get("video_count"),
                    json.dumps(row, default=str),
                ),
            )
    print(f"Loaded {len(df)} rows from {args.csv}")


if __name__ == "__main__":
    main()
