-- Q4. What are the main dropoff points in the order process?
-- Dropped orders and lost GMV by the last stage reached and the reason.

select
    dropoff_stage,
    dropoff_reason,
    sum(dropped_orders) as dropped_orders,
    round(sum(dropped_orders)::numeric / sum(sum(dropped_orders)) over (), 4) as share_of_dropoffs,
    sum(lost_gmv) as lost_gmv
from {{ ref('dropoff_analysis') }}
group by dropoff_stage, dropoff_reason
order by dropped_orders desc, lost_gmv desc
