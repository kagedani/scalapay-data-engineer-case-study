-- Shipping company performance on paid orders: time from payment to fulfilment
-- and rate of orders lost in shipping (the dropoff attributable to the carrier).

select
    shipping.shipping_company_id,
    shipping.shipping_company_name,
    count(*) as assigned_orders,
    count(orders.paid_at) as paid_orders,
    count(orders.fulfilled_at) as fulfilled_orders,
    count(*) filter (where orders.dropoff_reason = 'lost_in_shipping') as lost_in_shipping_orders,
    {{ safe_ratio("count(*) filter (where orders.dropoff_reason = 'lost_in_shipping')", 'count(orders.paid_at)') }} as lost_in_shipping_rate,
    coalesce(sum(products.price) filter (where orders.dropoff_reason = 'lost_in_shipping'), 0) as lost_in_shipping_gmv,
    round(avg(orders.hours_to_fulfillment), 2) as avg_hours_to_fulfillment,
    round((percentile_cont(0.5) within group (order by orders.hours_to_fulfillment))::numeric, 2) as median_hours_to_fulfillment,
    round((percentile_cont(0.9) within group (order by orders.hours_to_fulfillment))::numeric, 2) as p90_hours_to_fulfillment
from {{ ref('fct_orders') }} as orders
inner join {{ ref('dim_shipping_companies') }} as shipping
    on orders.shipping_company_id = shipping.shipping_company_id
inner join {{ ref('dim_products') }} as products
    on orders.product_id = products.product_id
group by 1, 2
