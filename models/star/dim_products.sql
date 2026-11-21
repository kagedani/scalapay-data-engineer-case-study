-- One row per product. Price is the current price: the source has no history.

select
    product_id,
    price,
    category,
    {{ audit_run_ts() }} as insert_ts,
    {{ audit_run_ts() }} as last_update_ts
from {{ ref('stg_products') }}
