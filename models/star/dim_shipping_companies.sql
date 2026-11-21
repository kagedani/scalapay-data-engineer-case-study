-- One row per shipping company.

select
    shipping_company_id,
    shipping_company_name,
    {{ audit_run_ts() }} as insert_ts,
    {{ audit_run_ts() }} as last_update_ts
from {{ ref('stg_shipping_companies') }}
