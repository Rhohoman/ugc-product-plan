# UGC Product Optimization (ugc-product-plan)

Research TikTok Shop's top-selling products and their price, cost and margin, then build algorithms
to choose which products to make UGC content for.

- **Plan & architecture:** [docs/PLAN.md](docs/PLAN.md)
- **Creator business plan (road to 10K sales/month):** [docs/TIKTOK_SHOP_AFFILIATE_PLAN.md](docs/TIKTOK_SHOP_AFFILIATE_PLAN.md)
- **Database schema:** [db/schema.sql](db/schema.sql)
- **CSV ingest:** `src/ugc/ingest/load_csv.py`

## Branches
- `master`: stable; merge via PR
- `ryho-branch`: ryho's work
- `jwng-branch`: jwng's work

## Setup
```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in DATABASE_URL
psql "$DATABASE_URL" -f db/schema.sql
PYTHONPATH=src python -m ugc.ingest.load_csv export.csv --source kalodata
```
