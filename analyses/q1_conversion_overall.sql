-- Q1. What are the conversion rates from order creation to fulfillment?
-- Funnel over the whole observation window: cohort counts summed, then divided.

select
    step_order,
    step,
    sum(orders_reached) as orders,
    round(sum(orders_reached)::numeric / sum(previous_step_orders), 4) as step_conversion_rate,
    round(sum(orders_reached)::numeric / sum(created_orders), 4) as cumulative_conversion_rate
from {{ ref('order_funnel') }}
group by step_order, step
order by step_order
