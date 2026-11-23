# 🛒 Order funnel analytics with dbt and Postgres

A dbt project that turns four raw CSV files (customers, orders, products,
shipping companies) into a star schema and a set of marts, and answers the
case-study questions on order conversion, product categories, subscription
tiers and dropoffs.

**👋 Who is reading?**

- 🧑 **If you are a person**, the next section is [For humans](#-for-humans): what
  the project found, how to run it, and why it looks the way it does.
- 🤖 **If you are an AI agent**, skip to [For agents](#-for-agents): a compact map
  of commands, files and invariants.

---

## 🧑 For humans

### 📊 Results

- **[`docs/insights.md`](docs/insights.md)** has the findings, the charts and
  the recommendations. Start there.
- **[`analyses/`](analyses)** holds one SQL query per question. Each query reads
  the marts and nothing else.
- **[`docs/img/`](docs/img)** holds the charts, rendered from those queries.

### 🚀 Run it

You need Docker and Make.

1. Copy the four source files into `data/` (git ignores them):
   `data/customers.csv`, `data/orders.csv`, `data/products.csv`,
   `data/shipping_company.csv`.
2. Run `make start`. It builds the image, starts Postgres and dbt, installs the
   dbt packages and loads the CSV files into the `raw_data` schema with
   `dbt seed`. The container reloads them on every start.
3. Run `make all`. It builds and tests every model, then renders the charts.

| Target | What it does |
|---|---|
| `make start` / `make stop` | Start or stop the containers |
| `make build` | `dbt build`: every model, test and unit test |
| `make full-refresh` | `dbt build --full-refresh`, which also rebuilds the incremental `fct_orders` |
| `make insights` | Compiles `analyses/` and renders `docs/img/*.png` (run a build first) |
| `make all` | `build` followed by `insights` |
| `make docs` | Serves the dbt docs and lineage graph on http://localhost:8080 |
| `make shell` | Opens a shell in the dbt container |
| `make clean` | Removes the containers, the database volume and generated files |

The expected build result is `PASS=114 WARN=6 ERROR=0`. The six warnings
come from tests on the raw sources: they document the data quality issues
listed below.

**Partial runs.** `make build` takes a dbt selector:

```bash
make build SELECT="path:models/star+"   # star and everything downstream
make build SELECT="path:models/mart"    # marts only
make build SELECT="+tier_behavior"      # one mart and everything it needs
```

dbt only builds what you select, so the upstream objects must already exist in
the database from an earlier run.

**Charts.** `scripts/insights_charts.py` runs inside the dbt container, which
already has pandas, matplotlib and psycopg2 from `poetry.lock`. It reads the
compiled queries from `target/`, so it needs a build and a compile first;
`make insights` does both steps.

### 🏗️ Architecture

```
data/*.csv ──dbt seed──▶ raw_data ──▶ staging ──▶ star ──▶ mart ──▶ analyses/ ──▶ docs/img/
                        (tables)    (views)    (tables)  (tables)
```

| Layer | Materialisation | Role |
|---|---|---|
| `staging` | view | One model per source. Cleans, renames, casts and deduplicates, 1:1 with the source. |
| `star` | table | Kimball dimensions and facts, with enforced contracts. |
| `mart` | table | Aggregates built to answer the questions. |

dbt's own guide calls the dimensional layer "marts". Here `star` holds the
dimensional model and `mart` holds the consumption aggregates. A custom
`generate_schema_name` writes each layer to a schema with its own name
(`staging`, `star`, `mart`) instead of dbt's default `public_staging`.

Star models:

- `dim_customers`: one row per customer, current attributes.
- `dim_customer_subscriptions`: subscription tier history (SCD2).
- `dim_products` and `dim_shipping_companies`.
- `fct_orders`: one row per order with a timestamp per funnel stage.

### ❓ Questions, marts and queries

| Question in the brief | Mart | Query in `analyses/` |
|---|---|---|
| Conversion rates from order creation to fulfillment | `order_funnel` | `q1_conversion_overall`, `q1_conversion_by_cohort` |
| Product categories with the highest order volumes | `category_performance` | `q2_category_volumes` |
| How subscription tiers affect customer behaviour | `tier_behavior`, built on `customer_subscription_periods` | `q3_tier_behavior` |
| Main dropoff points in the order process | `dropoff_analysis`, `shipping_performance` | `q4_dropoff_points`, `q4_dropoffs_by_cohort_month`, `q4_carrier_losses` |

`customer_lifetime_value` adds context to the tier question. Each mart answers
its question with one query on top; no analysis rebuilds logic the marts lack.

### 📏 Metric definitions

- **GMV**: sum of the current product price over fulfilled orders.
  **Lost GMV**: the same sum over dropped orders.
- **Paid**: the order reached the `payment` stage.
- **Lost in shipping**: a dropoff after payment caused by the carrier.
- **Customer lifetime value**: historical only, the GMV a customer has already
  generated inside the data window. The project makes no predictions.
- **Observation window**: from the first to the last order creation in the
  data.
- **Exposure**: the days a subscription period overlaps the window. The marts
  show any period that overlaps the window, even with zero orders, and drop
  periods entirely outside it. A period with at least `min_exposure_days` (30)
  of exposure has `is_comparable = true`, and only those periods feed the
  per-30-day rates.

### 🧭 Design decisions

**Tier history as a mini-dimension, built in SQL.** The customers file already
holds every tier change with its `updated_at`. `dim_customer_subscriptions`
turns those events into half-open periods `[valid_from, valid_to)` with
`lead()`, and uses `9999-12-31` for the open period. I did not use a dbt
snapshot: a snapshot records changes between runs, and the history already
sits in the source.

**Tier at order time lives in the marts.** `fct_orders` has no foreign key to a
subscription period. The macro `join_subscription_at_order_time()` joins each
order to the period valid at `created_at`, and a singular test checks that
every order matches exactly one period.

**Orders as an accumulating snapshot.** `fct_orders` pivots the order events
into one row per order, with a timestamp per stage, the last status and the
dropoff reason. It loads incrementally (see below).

**No intermediate layer.** The event pivot and the SCD2 each have one consumer,
so they live inside the model that uses them.

**Keys.** Star models have enforced contracts, so Postgres creates real primary
keys. Foreign keys are `relationships` tests rather than database constraints:
dbt rebuilds a dimension with drop and rename, and a real foreign key from the
fact would block that. Marts have no contracts; uniqueness tests cover their
grain.

**Tests by layer.** Tests on raw sources warn: they describe data you do not
control. From staging onwards a failing test stops the build.

**Alternative I considered: customer events as a fact.** A
`fct_subscription_changes` table with a type 1 `dim_customers` would serve
event questions better (upgrades per month, churn). The tier questions here
need the tier at order time, which means intervals, so I kept the SCD2. In
production I would keep both: the event fact as the record, the mini-dimension
derived from it for point-in-time joins.

### 🔁 Incremental loading of `fct_orders`

Each run finds the watermark, `max(last_event_at)` already loaded minus
`fct_orders_lookback_days`. It rebuilds every order whose last event falls at
or after the watermark, from all of that order's events, and replaces those
rows (`delete+insert` on `order_id`; Postgres 13 has no `MERGE`).

**Variables** (set in `dbt_project.yml`, override with `make build VARS=...`):

| Variable | Default | When to change it |
|---|---|---|
| `fct_orders_lookback_days` | `0` | Raise it if events can arrive late. A wider window rebuilds more orders per run. |
| `min_exposure_days` | `30` | Minimum overlap with the window for a subscription period to enter tier comparisons. |
| `subscription_tiers` | `['free', 'premium', 'enterprise']` | Add a new tier in its rank position. The order tells an upgrade from a downgrade, and the list feeds every `subs_tier` test. |

Why it works this way:

- The orders file is cumulative: each delivery carries the full event history.
  A delta file fails the build (the `not_null` test on `created_at` or the
  reconciliation test). Deltas need an append-only landing table with an
  ingestion timestamp as the watermark.
- The watermark uses business time. With lookback 0, a late event on an order
  already loaded goes unnoticed by the incremental run; the test
  `assert_fct_orders_in_sync_with_staging` catches it. The fix is a larger
  lookback or `make full-refresh`.
- The model filters on the watermark after the pivot. `stg_orders` is a view
  that deduplicates with a window function, and Postgres cannot push the filter
  below it, so filtering earlier would read the source twice for no saving.
- `on_schema_change='fail'` stops incremental runs when a column is added,
  removed or retyped, until someone runs a deliberate full refresh. A full
  refresh resets `insert_ts`.
- Hard deletes in the source do not propagate.

### 🧹 Data quality findings

- `customers`: 5 duplicated events.
- `orders`: 2 duplicated events.
- `products`: product 26 appears twice with identical values; products 47 and
  48 have no category (staging maps them to `UNDEFINED`).
- Category spelling varies (`electronics`, `Home&Garden`, `Home & Garden`).
  Staging normalises it with a code rule rather than a mapping seed, because
  the noise is spelling only, with no synonyms.
- The brief does not mention the `Sports` category or the `GSO Delivery`
  carrier, but both appear in the data.

Deduplication rule in staging: identical rows collapse into one; conflicting
versions of the same event keep the latest `updated_at`; a conflict with equal
timestamps fails the build, because no rule can pick a winner.

### 🚧 Limitations and next steps

- **Prices have no history.** Products carry neither a version nor a
  timestamp, so a price change rewrites the GMV of past orders. Two fixes:
  - Best: get the price paid into the order data at the source.
  - Otherwise: a dbt snapshot on products with `strategy: check` on `price`
    and `category`, and a point-in-time join from orders to the product
    version. That history would start at the first run and use processing
    time, so a price changed on Monday and loaded on Wednesday would count
    from Wednesday.
- **Six months of data**, with partial first and last months, and small
  samples for enterprise customers and carrier losses. `docs/insights.md`
  covers the analytical limits.
- **At larger scale**: materialise staging as tables, add an index on
  `fct_orders.last_event_at`, and land orders append-only.
- **Out of scope**: pre-commit hooks, CI and SQL linting.

### 🛠️ Technical notes

Postgres and dbt behaviours that cost time during the build:

- On Postgres 13, `extract(epoch from ...)` returns `double precision`, and
  `round(double, n)` does not exist. Cast to `numeric` before rounding; the
  `duration_between()` macro does it.
- A unit test of an incremental model needs `is_incremental: true` and a
  `this` input. Give that input with `format: sql`: dbt then needs no existing
  table to infer columns, and the test passes on an empty database.
- Postgres cuts identifiers at 63 characters, and dbt uses the unit test name
  in the relations it creates. Keep unit test names under that limit.
- In Jinja, `{%- -%}` placed after a SQL `--` comment strips the newline and
  glues the next line into the comment.
- Postgres rejects `share` as a column alias without `as`: write `as share`.
- `fct_orders` keeps string columns as `text`. A `varchar(n)` column would need
  an explicit cast in the model, and Postgres truncates on explicit casts
  without an error. `accepted_values` tests guard the domain instead.

### 🧰 Changes to the provided scaffold

- **Dockerfile**: copies `poetry.lock` and installs the dev group, so the image
  uses pinned versions (dbt-core 1.10.10, dbt-postgres 1.9.0) plus pandas and
  matplotlib for the charts.
- **docker-compose**: the dbt container runs as the host user, so generated
  files on Linux hosts belong to you and not to root; port 8080 is exposed for
  the dbt docs.
- **Makefile**: `make start` waits for the setup to finish instead of sleeping
  10 seconds; new targets `build`, `full-refresh`, `docs`, `insights` and
  `all`; the duplicated `test-environment` commands are gone.
- **entrypoint.sh**: stops after two minutes with the real `dbt debug` error
  instead of looping on "PostgreSQL is unavailable".

---

## 🤖 For agents

Compact reference. Open the linked files for detail only when the task needs it.

**Environment**

- Postgres 13 and dbt-core 1.10.10 run in Docker. `make start` returns after
  `Environment is ready!`.
- Run commands from the repo root on the host. Every target except `shell` and
  `docs` runs without a TTY.
- `make build [SELECT="<selector>"] [VARS="<yaml>"]`, `make insights`,
  `make all`, `make full-refresh`.
- Raw dbt: `docker compose exec -T dbt dbt <command>`.
- SQL: `docker compose exec -T postgres psql -U postgres -d funnel_analysis -c "<sql>"`.
- Baseline: `PASS=114 WARN=6 ERROR=0`. The 6 WARN are source tests and are
  expected. Any change in counts needs an explanation.

**Layout**

| Path | Content |
|---|---|
| `models/sources/sources.yml` | Sources in schema `raw_data` (seeded from `data/*.csv`, not versioned) |
| `models/staging/` | `stg_*` views, YAML `_staging.yml` |
| `models/star/` | `dim_*`, `fct_orders`; `_star.yml` (contracts), `_star_unit_tests.yml` |
| `models/mart/` | 7 marts, no prefix; grain and columns in `_mart.yml` |
| `macros/mart_helpers.sql` | `join_subscription_at_order_time`, `observation_window`, `tier_rank`, `gmv`, `safe_ratio`, `per_30_days` |
| `macros/` (other) | `duration_between`, `audit_run_ts`, `generate_schema_name` |
| `tests/singular/` | Cross-model invariants (reconciliation, SCD2 contiguity, GMV consistency) |
| `analyses/q*.sql` | One query per brief question, reads marts only |
| `scripts/insights_charts.py` | Reads compiled `analyses/` from `target/`, writes `docs/img/*.png` |
| `docs/insights.md` | Findings; its numbers come from `analyses/` |

**⚠️ Invariants: do not break these**

- Mart grain, column names and values feed `analyses/`, the chart script and
  `docs/insights.md`. If a change alters them, update all three or ask first.
- Star models enforce contracts: a column change needs the matching YAML
  change. `fct_orders` has `on_schema_change='fail'`, so after a schema change
  run `make full-refresh`.
- Keep the GMV definition in the `gmv()` macro. `assert_marts_gmv_consistent`
  compares every mart with the star.
- Join tier to orders only through `join_subscription_at_order_time()`.
  Periods are half-open; `9999-12-31` marks the current one.
- Canonical values stay in SQL: country `UPPER_SNAKE`, tiers lowercase,
  category `UPPER_SNAKE` with `UNDEFINED`, `dropoff_reason` `lower_snake`.
  Readable labels belong in the Python script only.

**Conventions (dbt 1.10)**

- `data_tests:`, never `tests:`. Test arguments go under `arguments:`;
  `config: severity:` sits at the same level.
- YAML per layer is named `_<layer>.yml`. Sources warn, everything else errors.
- Star tables carry `insert_ts` and `last_update_ts` from `audit_run_ts()`;
  marts do not.
- Use Conventional Commits, one commit per logical change.

**Check a change**

1. `make build`: counts match the baseline.
2. For a mart change, diff the mart before and after with `psql`.
3. `make insights`: the PNGs change only if the data changed.
