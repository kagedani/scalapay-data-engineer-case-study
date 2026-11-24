-- A dropoff reason appears only on the last event of an order, so it describes
-- the stage where the order stopped. A fulfilled order has no dropoff.

with dropoffs_not_on_last_event as (

    select
        order_id,
        'dropoff on an event followed by another stage' as issue
    from (
        select
            order_id,
            dropoff_reason,
            row_number() over (partition by order_id order by updated_at desc, order_event_id desc) as recency_rank
        from {{ ref('stg_orders') }}
    ) as ranked
    where dropoff_reason is not null
        and recency_rank > 1

),

inconsistent_orders as (

    select
        order_id,
        'outcome or dropoff stage inconsistent with dropoff reason' as issue
    from {{ ref('fct_orders') }}
    where (order_outcome = 'dropped') <> (dropoff_reason is not null)
        or (dropoff_reason is not null and dropoff_stage <> last_status)
        or (dropoff_reason is null and dropoff_stage is not null)

)

select * from dropoffs_not_on_last_event
union all
select * from inconsistent_orders
