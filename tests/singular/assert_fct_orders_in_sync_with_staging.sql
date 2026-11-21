-- Every order in fct_orders reflects all its events in stg_orders: same latest event
-- and same number of stages reached. Catches a late event on an already loaded order,
-- older than the incremental watermark, which no other test sees (the order count
-- still reconciles). Remedy: raise fct_orders_lookback_days or run --full-refresh.

with staged as (

    select
        order_id,
        max(updated_at) as last_event_at,
        count(distinct order_status) as stages_reached
    from {{ ref('stg_orders') }}
    group by order_id

),

loaded as (

    select
        order_id,
        last_event_at,
        (created_at is not null)::integer
            + (paid_at is not null)::integer
            + (fulfilled_at is not null)::integer as stages_reached
    from {{ ref('fct_orders') }}

)

select
    staged.order_id,
    staged.last_event_at as staged_last_event_at,
    loaded.last_event_at as loaded_last_event_at,
    staged.stages_reached as staged_stages,
    loaded.stages_reached as loaded_stages
from staged
inner join loaded
    on staged.order_id = loaded.order_id
where staged.last_event_at <> loaded.last_event_at
    or staged.stages_reached <> loaded.stages_reached
