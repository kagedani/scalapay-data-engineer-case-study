-- Every order in the raw source becomes exactly one row of fct_orders.
-- Catches orders lost or duplicated by staging or by the incremental logic.

with source_orders as (

    select count(distinct order_id) as order_count
    from {{ source('raw_data', 'orders') }}

),

fact_orders as (

    select count(*) as order_count from {{ ref('fct_orders') }}

)

select
    source_orders.order_count as source_order_count,
    fact_orders.order_count as fact_order_count
from source_orders
cross join fact_orders
where source_orders.order_count <> fact_orders.order_count
