-- Ordering behaviour by subscription tier at order time (point-in-time).
-- Conversion and dropoff use every order. Exposure-normalised metrics use only
-- comparable periods (is_comparable), so short periods do not distort them.

with orders as (

    select
        subscriptions.subs_tier,
        orders.customer_id,
        orders.paid_at,
        orders.fulfilled_at,
        orders.order_outcome,
        orders.dropoff_reason,
        products.price
    from {{ ref('fct_orders') }} as orders
    {{ join_subscription_at_order_time('orders', 'subscriptions') }}
    inner join {{ ref('dim_products') }} as products
        on orders.product_id = products.product_id

),

tier_orders as (

    select
        subs_tier,
        count(distinct customer_id) as ordering_customers,
        count(*) as orders,
        count(paid_at) as paid_orders,
        count(fulfilled_at) as fulfilled_orders,
        count(*) filter (where dropoff_reason = 'card_declined') as card_declined_orders,
        count(*) filter (where dropoff_reason = 'customer_abandoned') as customer_abandoned_orders,
        count(*) filter (where dropoff_reason = 'inventory_shortage') as inventory_shortage_orders,
        count(*) filter (where dropoff_reason = 'lost_in_shipping') as lost_in_shipping_orders,
        coalesce(sum(price) filter (where order_outcome = 'fulfilled'), 0) as gmv,
        round(avg(price) filter (where order_outcome = 'fulfilled'), 2) as avg_fulfilled_order_value
    from orders
    group by subs_tier

),

tier_exposure as (

    select
        subs_tier,
        count(*) as comparable_periods,
        sum(exposure_days) as comparable_exposure_days,
        sum(orders) as comparable_orders,
        sum(gmv) as comparable_gmv
    from {{ ref('customer_subscription_periods') }}
    where is_comparable
    group by subs_tier

)

select
    tier_orders.subs_tier,
    {{ tier_rank('tier_orders.subs_tier') }} as tier_rank,
    tier_orders.ordering_customers,
    tier_orders.orders,
    tier_orders.paid_orders,
    tier_orders.fulfilled_orders,
    round(tier_orders.paid_orders::numeric / tier_orders.orders, 4) as payment_rate,
    round(tier_orders.fulfilled_orders::numeric / nullif(tier_orders.paid_orders, 0), 4) as fulfillment_rate,
    round(tier_orders.fulfilled_orders::numeric / tier_orders.orders, 4) as overall_conversion_rate,
    tier_orders.card_declined_orders,
    tier_orders.customer_abandoned_orders,
    tier_orders.inventory_shortage_orders,
    tier_orders.lost_in_shipping_orders,
    tier_orders.gmv,
    tier_orders.avg_fulfilled_order_value,
    coalesce(tier_exposure.comparable_periods, 0) as comparable_periods,
    tier_exposure.comparable_exposure_days,
    round(tier_exposure.comparable_orders * 30 / nullif(tier_exposure.comparable_exposure_days, 0), 4) as orders_per_30_days,
    round(tier_exposure.comparable_gmv * 30 / nullif(tier_exposure.comparable_exposure_days, 0), 2) as gmv_per_30_days
from tier_orders
left join tier_exposure
    on tier_orders.subs_tier = tier_exposure.subs_tier
