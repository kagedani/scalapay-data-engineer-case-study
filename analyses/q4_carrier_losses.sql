-- Q4. Orders lost in shipping and fulfilment speed by shipping company.

select
    shipping_company_name,
    paid_orders,
    lost_in_shipping_orders,
    lost_in_shipping_rate,
    lost_in_shipping_gmv,
    median_hours_to_fulfillment,
    p90_hours_to_fulfillment
from {{ ref('shipping_performance') }}
order by lost_in_shipping_rate desc
