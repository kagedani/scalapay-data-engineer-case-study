-- Order volumes, conversion and GMV by product category and month of creation.
-- GMV counts fulfilled orders only, at the current product price.

select
    products.category,
    date_trunc('month', orders.created_at)::date as order_month,
    count(*) as created_orders,
    count(orders.paid_at) as paid_orders,
    count(orders.fulfilled_at) as fulfilled_orders,
    count(*) filter (where orders.order_outcome = 'dropped') as dropped_orders,
    {{ safe_ratio('count(orders.fulfilled_at)', 'count(*)') }} as fulfillment_rate,
    coalesce({{ gmv() }}, 0) as gmv,
    coalesce({{ gmv('dropped') }}, 0) as lost_gmv
from {{ ref('fct_orders') }} as orders
inner join {{ ref('dim_products') }} as products
    on orders.product_id = products.product_id
group by 1, 2
