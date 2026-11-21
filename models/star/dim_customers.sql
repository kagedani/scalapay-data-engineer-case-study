-- One row per customer (type 1). Country and email never change in the source
-- (checked by a singular test), so no history is kept for them.
-- The tier history lives in dim_customer_subscriptions.

with customer_events as (

    select * from {{ ref('stg_customers') }}

),

ranked as (

    select
        *,
        min(updated_at) over (partition by customer_id) as first_seen_at,
        row_number() over (
            partition by customer_id
            order by updated_at desc, customer_event_id desc
        ) as recency_rank
    from customer_events

)

select
    customer_id,
    email,
    country,
    -- first event, used as a proxy for the registration date
    first_seen_at,
    subs_tier as current_subs_tier,
    {{ audit_run_ts() }} as insert_ts,
    {{ audit_run_ts() }} as last_update_ts
from ranked
where recency_rank = 1
