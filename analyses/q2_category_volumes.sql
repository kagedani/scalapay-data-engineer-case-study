-- Q2. Which product categories have the highest order volumes?
-- Volume = created orders. GMV is shown too: the two rankings differ.

select
    category,
    sum(created_orders) as orders,
    sum(fulfilled_orders) as fulfilled_orders,
    round(sum(fulfilled_orders)::numeric / sum(created_orders), 4) as fulfillment_rate,
    sum(gmv) as gmv,
    sum(lost_gmv) as lost_gmv
from {{ ref('category_performance') }}
group by category
order by orders desc
