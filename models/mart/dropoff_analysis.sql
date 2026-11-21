-- Where orders drop off and how much value is lost, by stage and reason, broken
-- down by tier at order time, product category and shipping company.
-- Lost GMV = current price of the product of each dropped order.
-- Fine grain on purpose: consumers aggregate up to the breakdown they need.

select
    orders.dropoff_stage,
    orders.dropoff_reason,
    subscriptions.subs_tier as subs_tier_at_order,
    products.category,
    shipping.shipping_company_name,
    count(*) as dropped_orders,
    sum(products.price) as lost_gmv
from {{ ref('fct_orders') }} as orders
{{ join_subscription_at_order_time('orders', 'subscriptions') }}
inner join {{ ref('dim_products') }} as products
    on orders.product_id = products.product_id
inner join {{ ref('dim_shipping_companies') }} as shipping
    on orders.shipping_company_id = shipping.shipping_company_id
where orders.order_outcome = 'dropped'
group by 1, 2, 3, 4, 5
