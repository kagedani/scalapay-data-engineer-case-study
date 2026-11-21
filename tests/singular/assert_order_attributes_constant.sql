-- Product, customer and shipping company never change within an order.
-- fct_orders relies on this when it pivots events with max().

select
    order_id,
    count(distinct product_id) as product_versions,
    count(distinct customer_id) as customer_versions,
    count(distinct shipping_company_id) as shipping_company_versions
from {{ ref('stg_orders') }}
group by order_id
having count(distinct product_id) > 1
    or count(distinct customer_id) > 1
    or count(distinct shipping_company_id) > 1
