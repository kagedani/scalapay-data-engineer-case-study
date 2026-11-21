-- One row per order lifecycle event, cleaned and deduplicated.
-- Same dedup rule as stg_customers, keyed on order_event_id.

with source as (

    select * from {{ source('raw_data', 'orders') }}

),

renamed as (

    select
        event_id::integer as order_event_id,
        order_id::integer as order_id,
        product_id::integer as product_id,
        customer_id::integer as customer_id,
        shipping_company_id::integer as shipping_company_id,
        lower(trim(status))::text as order_status,
        -- lower-cased, inner spaces as '_' ('card declined' -> 'card_declined')
        lower(regexp_replace(nullif(trim(dropoff), ''), '\s+', '_', 'g'))::text as dropoff_reason,
        updated_at::timestamp as updated_at
    from source

),

deduplicated as (

    select distinct * from renamed

),

latest_version as (

    select
        *,
        max(updated_at) over (partition by order_event_id) as latest_updated_at
    from deduplicated

)

select
    order_event_id,
    order_id,
    product_id,
    customer_id,
    shipping_company_id,
    order_status,
    dropoff_reason,
    updated_at
from latest_version
where updated_at = latest_updated_at
