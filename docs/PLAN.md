# UGC Product Optimization: Architecture & Plan

**Goal:** Find the top 50 best-selling TikTok Shop products, record their selling price and estimated
landed cost (and the margin between them), track them over time, and build up a dataset we can
later run ranking/forecasting algorithms on to pick products for UGC content.

---

## 1. Where the data comes from

TikTok has **no public "best sellers" API**. The official TikTok Shop Partner API only returns data
for shops *you own or are authorized for*. So "top sellers across the marketplace" has to come from
one of these:

| Source | What you get | Cost | Notes |
|---|---|---|---|
| **Third-party TikTok Shop analytics** (Kalodata, FastMoss, EchoTik, Shoplus, Tabcut) | Ranked product lists, est. units sold, GMV, price, shop, linked creators/videos, trends | ~$50–$200/mo per seat | **Recommended starting point.** Most have CSV export; some have APIs on higher tiers. Sales numbers are *estimates*. |
| **TikTok Creative Center → Top Products** | Trending product categories/ads, CTR, CVR, popularity | Free | Good signal, but category-level, not exact SKU sales. |
| **TikTok Shop storefront pages** (product page "X sold") | Price, sold count, rating, reviews, shop | Free | Scraping is against TikTok's ToS and gets blocked. Use only for manual spot-checks. |
| **Official TikTok Shop Partner API** | Exact orders/settlements/fees for **our own** shop | Free (app approval) | Use later, once we're selling, to get ground-truth costs and fees. |

**Recommendation:** Pay for **one** analytics tool for a month (Kalodata or FastMoss are the most
common) and run a weekly CSV/API pull. Validate a sample of 5–10 products by hand against the live
product pages.

## 2. What "cost" means: three numbers per product

1. **Retail price**: what the buyer pays on TikTok Shop (from the analytics tool).
2. **Product/COGS cost**: what it costs to source. Look up the same or a similar item on
   **Alibaba / 1688 / AliExpress / CJdropshipping** and record unit cost + MOQ + shipping.
   Image search (Google Lens, AliExpress image search) works well for matching.
3. **TikTok Shop fees + creator commission**: referral fee (roughly 6–8% in the US; check the current
   rate for the category), affiliate commission (often 10–20%, and the analytics tools show this), and
   shipping/fulfillment.

`est_margin = price − COGS − shipping − platform_fee − affiliate_commission`

## 3. Workflow

```
 [Analytics tool CSV/API]──┐
 [Creative Center]─────────┼──► ingest (Python) ──► raw JSON/CSV in object storage (never edited)
 [Manual sourcing lookups]─┘                         │
                                                     ▼
                                       Postgres: products, snapshots, costs
                                                     │
                                                     ▼
                         DuckDB / notebooks ──► top-50 report + features for algorithms
```

**Weekly cadence**
1. Pull the top 200 products (more than 50, so we can see movement in and out of the top 50) → `data/raw/YYYY-MM-DD/`.
2. Load into `product_snapshot` (one row per product per pull, so we build history).
3. For any *new* product in the top 50, fill in a `sourcing_cost` row (manual at first, semi-automated later).
4. Run the `top50_with_margin` view → share the report.

**Phase plan**
| Phase | Weeks | Deliverable |
|---|---|---|
| 0. Setup | 1 | Repo, DB, analytics tool account, schema loaded |
| 1. First top 50 | 1–2 | Top-50 list with price + COGS + margin, manually verified |
| 2. Automate | 2–4 | Scheduled weekly ingest (GitHub Actions cron), history accumulating |
| 3. Enrich | 4–6 | Creator/video data per product (views, # creators, engagement) |
| 4. Algorithms | 6+ | Product scoring model: trend velocity, margin, competition, UGC-fit |

## 4. Recommended tech stack

Start small and cheap, but pick tools that still work at millions of rows.

| Layer | Pick | Why |
|---|---|---|
| **Primary DB** | **PostgreSQL on Supabase** (or Neon) | Free tier to start, real SQL, JSONB for messy fields, built-in table UI so non-engineers can browse/edit sourcing costs. Scales to tens of millions of snapshot rows. |
| **Raw storage** | **Cloudflare R2** or AWS S3 (Parquet + original CSV/JSON) | Cheap, keeps untouched source data so we can re-process later. R2 has no egress fees. |
| **Analytics / algorithms** | **Python + DuckDB + Jupyter**, pandas/polars, scikit-learn, LightGBM | DuckDB queries Parquet/Postgres directly on a laptop, fast and free. This is the "space to build algorithms." |
| **Scheduling** | **GitHub Actions cron** → later Prefect/Dagster if pipelines grow | Free, lives in this repo. |
| **Dashboards** | Supabase table view → **Metabase** or Streamlit | Quick top-50 views for the team. |
| **Secrets** | GitHub Actions secrets + local `.env` (git-ignored) | Never commit API keys. |
| **If we outgrow it** | BigQuery or Snowflake | Only once we're past ~100M rows or need heavy joins; not needed yet. |

**Rough monthly cost to start:** $0 infra (free tiers) + one analytics tool subscription (~$50–$200).

## 5. Algorithm ideas for later

- **Trend velocity:** week-over-week change in est. units sold; flag products accelerating into the top 50.
- **Opportunity score:** `margin × demand growth ÷ competition` (competition = # of shops/creators selling it).
- **UGC fit:** correlate product traits (price band, category, demo-ability) with video engagement.
- **Saturation detection:** creator count rising faster than sales means the product is getting crowded.
- **Forecasting:** LightGBM/Prophet on the snapshot history to predict next-week sales rank.

## 6. Team split (suggested)

- **ryho-branch:** ingest pipeline + DB schema + scheduling.
- **jwng-branch:** sourcing-cost lookups, margin model, notebooks/analysis.
- Merge into `master` via pull requests.

## 7. Risks

- Third-party sales figures are **estimates**, so treat them as relative rankings, not exact numbers.
- Respect TikTok's and each tool's ToS; don't build scrapers against TikTok directly.
- Product matching for COGS is fuzzy; store a `match_confidence` and the supplier URL.
