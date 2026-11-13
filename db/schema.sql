-- UGC Product Optimization: core schema (PostgreSQL)

create table if not exists product (
    product_id      text primary key,          -- TikTok Shop product id (or tool's id)
    title           text not null,
    category        text,
    shop_name       text,
    product_url     text,
    image_url       text,
    first_seen_at   timestamptz not null default now(),
    attributes      jsonb default '{}'::jsonb   -- anything extra the source gives us
);

-- One row per product per data pull (builds history for trend algorithms)
create table if not exists product_snapshot (
    id                  bigserial primary key,
    product_id          text not null references product(product_id),
    captured_at         timestamptz not null,
    source              text not null,          -- 'kalodata', 'fastmoss', 'manual', ...
    region              text default 'US',
    sales_rank          int,
    price               numeric(10,2),
    currency            text default 'USD',
    est_units_sold_7d   int,
    est_units_sold_30d  int,
    est_gmv_30d         numeric(14,2),
    rating              numeric(3,2),
    review_count        int,
    affiliate_commission_pct numeric(5,2),
    creator_count       int,
    video_count         int,
    raw                 jsonb,
    unique (product_id, captured_at, source)
);
create index if not exists idx_snapshot_time on product_snapshot (captured_at desc);

-- Sourcing / COGS lookups (Alibaba, 1688, AliExpress, CJ, ...)
create table if not exists sourcing_cost (
    id                  bigserial primary key,
    product_id          text not null references product(product_id),
    supplier            text,
    supplier_url        text,
    unit_cost           numeric(10,2),
    moq                 int,
    shipping_per_unit   numeric(10,2),
    match_confidence    text check (match_confidence in ('exact','similar','guess')),
    checked_at          timestamptz not null default now(),
    notes               text
);

-- Latest top 50 with estimated margin
create or replace view top50_with_margin as
with latest as (
    select distinct on (product_id) *
    from product_snapshot
    order by product_id, captured_at desc
), cost as (
    select distinct on (product_id) *
    from sourcing_cost
    order by product_id, checked_at desc
)
select
    l.sales_rank, p.title, p.category, p.shop_name,
    l.price, l.est_units_sold_30d, l.est_gmv_30d,
    c.unit_cost, c.shipping_per_unit,
    l.affiliate_commission_pct,
    round(l.price
          - coalesce(c.unit_cost,0) - coalesce(c.shipping_per_unit,0)
          - l.price * 0.08                                   -- assumed platform fee; adjust
          - l.price * coalesce(l.affiliate_commission_pct,0)/100, 2) as est_margin,
    l.captured_at
from latest l
join product p using (product_id)
left join cost c using (product_id)
order by l.est_units_sold_30d desc nulls last
limit 50;
