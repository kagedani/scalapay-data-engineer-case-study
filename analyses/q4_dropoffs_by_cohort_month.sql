-- Q4. Dropoffs over time: dropped orders by month of order creation and reason.

select
    cohort_month,
    dropoff_reason,
    sum(dropped_orders) as dropped_orders
from {{ ref('dropoff_analysis') }}
group by cohort_month, dropoff_reason
order by cohort_month, dropoff_reason
