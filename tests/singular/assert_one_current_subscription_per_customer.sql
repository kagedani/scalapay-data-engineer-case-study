-- Every customer has exactly one open subscription period.

select
    customers.customer_id,
    count(subscriptions.customer_id) as current_periods
from {{ ref('dim_customers') }} as customers
left join {{ ref('dim_customer_subscriptions') }} as subscriptions
    on customers.customer_id = subscriptions.customer_id
    and subscriptions.is_current
group by customers.customer_id
having count(subscriptions.customer_id) <> 1
