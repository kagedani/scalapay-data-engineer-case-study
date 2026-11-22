-- Q1. Conversion by monthly cohort, one row per month of order creation.
-- First and last months are partial (is_partial_month).

select
    cohort_month,
    is_partial_month,
    created_orders,
    max(step_conversion_rate) filter (where step = 'payment') as created_to_payment,
    max(step_conversion_rate) filter (where step = 'fulfilled') as payment_to_fulfilled,
    max(cumulative_conversion_rate) filter (where step = 'fulfilled') as created_to_fulfilled
from {{ ref('order_funnel') }}
group by cohort_month, is_partial_month, created_orders
order by cohort_month
