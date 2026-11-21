{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='order_id',
        on_schema_change='fail'
    )
}}

-- on_schema_change='fail': adding, removing or retyping a column stops incremental
-- runs until a deliberate --full-refresh. String columns stay text: a varchar(n)
-- column would need an explicit cast here (text does not fit varchar(n)), and explicit
-- casts truncate silently in Postgres. Their domain is checked by accepted_values.

-- Accumulating snapshot, one row per order: the event stream of stg_orders
-- pivoted into one timestamp per stage.
--
-- Incremental logic: find the orders with at least one event at or after the
-- watermark (max(last_event_at) already loaded, minus `fct_orders_lookback_days`),
-- then rebuild those orders from ALL their events and replace them
-- (delete+insert on order_id; Postgres 13 has no MERGE).
--
-- Assumptions: the orders file is cumulative (full event history, not a delta),
-- and with the default lookback 0 it adds no event older than the previous maximum.
-- A late event on a loaded order is flagged by assert_fct_orders_in_sync_with_staging:
-- raise the lookback or run --full-refresh.

with order_events as (

    select * from {{ ref('stg_orders') }}

    {% if is_incremental() %}
    where order_id in (
        select order_id
        from {{ ref('stg_orders') }}
        where updated_at >= (
            select coalesce(max(last_event_at), '1900-01-01'::timestamp)
                - interval '{{ var("fct_orders_lookback_days") }} days'
            from {{ this }}
        )
    )
    {% endif %}

),

-- product, customer and shipping company are constant within an order
-- (checked by a singular test), so max() just picks the single value.
pivoted as (

    select
        order_id,
        max(customer_id) as customer_id,
        max(product_id) as product_id,
        max(shipping_company_id) as shipping_company_id,
        min(updated_at) filter (where order_status = 'created') as created_at,
        min(updated_at) filter (where order_status = 'payment') as paid_at,
        min(updated_at) filter (where order_status = 'fulfilled') as fulfilled_at,
        max(updated_at) as last_event_at
    from order_events
    group by order_id

),

-- The dropoff reason is carried by the event of the last stage reached.
last_event as (

    select
        order_id,
        order_status as last_status,
        dropoff_reason
    from (
        select
            *,
            row_number() over (
                partition by order_id
                order by updated_at desc, order_event_id desc
            ) as recency_rank
        from order_events
    ) as ranked
    where recency_rank = 1

)

select
    pivoted.order_id,
    pivoted.customer_id,
    pivoted.product_id,
    pivoted.shipping_company_id,
    pivoted.created_at,
    to_char(pivoted.created_at, 'YYYYMMDD')::integer as creation_date_code,
    pivoted.paid_at,
    pivoted.fulfilled_at,
    pivoted.last_event_at,
    last_event.last_status,
    case when last_event.dropoff_reason is not null then last_event.last_status end as dropoff_stage,
    last_event.dropoff_reason,
    case
        when pivoted.fulfilled_at is not null then 'fulfilled'
        when last_event.dropoff_reason is not null then 'dropped'
        else 'in_progress'
    end::text as order_outcome,
    -- extract() returns double precision on Postgres 13: cast before rounding
    round((extract(epoch from pivoted.paid_at - pivoted.created_at) / 3600)::numeric, 2)::numeric(10, 2) as hours_to_payment,
    round((extract(epoch from pivoted.fulfilled_at - pivoted.paid_at) / 3600)::numeric, 2)::numeric(10, 2) as hours_to_fulfillment,
    {% if is_incremental() -%}
    coalesce(existing.insert_ts, {{ audit_run_ts() }}) as insert_ts,
    {%- else -%}
    {{ audit_run_ts() }} as insert_ts,
    {%- endif %}
    {{ audit_run_ts() }} as last_update_ts
from pivoted
inner join last_event
    on pivoted.order_id = last_event.order_id
{% if is_incremental() -%}
left join {{ this }} as existing
    on pivoted.order_id = existing.order_id
{%- endif %}
