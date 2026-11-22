-- Historical customer lifetime value, one row per customer (current tier).
-- CLV = GMV of the customer's fulfilled orders at current product prices.
-- Customers without orders are kept with zero value.

with customer_orders as (

    select
        orders.customer_id,
        count(*) as orders,
        count(*) filter (where orders.order_outcome = 'fulfilled') as fulfilled_orders,
        count(*) filter (where orders.order_outcome = 'dropped') as dropped_orders,
        {{ gmv() }} as historical_clv,
        min(orders.created_at) as first_order_at,
        max(orders.created_at) as last_order_at
    from {{ ref('fct_orders') }} as orders
    inner join {{ ref('dim_products') }} as products
        on orders.product_id = products.product_id
    group by orders.customer_id

),

subscription_changes as (

    select
        customer_id,
        count(*) - 1 as tier_changes
    from {{ ref('dim_customer_subscriptions') }}
    group by customer_id

)

select
    customers.customer_id,
    customers.country,
    customers.current_subs_tier,
    customers.first_seen_at,
    subscription_changes.tier_changes,
    customer_orders.first_order_at,
    customer_orders.last_order_at,
    coalesce(customer_orders.orders, 0) as orders,
    coalesce(customer_orders.fulfilled_orders, 0) as fulfilled_orders,
    coalesce(customer_orders.dropped_orders, 0) as dropped_orders,
    coalesce(customer_orders.historical_clv, 0) as historical_clv,
    {{ safe_ratio('customer_orders.historical_clv', 'customer_orders.fulfilled_orders', 2) }} as avg_fulfilled_order_value
from {{ ref('dim_customers') }} as customers
inner join subscription_changes
    on customers.customer_id = subscription_changes.customer_id
left join customer_orders
    on customers.customer_id = customer_orders.customer_id
