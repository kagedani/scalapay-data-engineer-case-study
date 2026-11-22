-- Funnel conversion by monthly cohort (month of order creation) and step.
-- The first and last cohort months may be partial: the data starts and ends mid-month.

with cohorts as (

    select
        date_trunc('month', created_at)::date as cohort_month,
        count(*) as created_orders,
        count(paid_at) as paid_orders,
        count(fulfilled_at) as fulfilled_orders,
        -- first and last month of the observation window, i.e. of the data
        min(date_trunc('month', created_at)::date) over () as first_cohort_month,
        max(date_trunc('month', created_at)::date) over () as last_cohort_month
    from {{ ref('fct_orders') }}
    group by 1

),

steps as (

    select
        cohort_month, 1 as step_order, 'created' as step, created_orders as orders_reached, created_orders as previous_step_orders, created_orders,
        cohort_month in (first_cohort_month, last_cohort_month) as is_partial_month
    from cohorts
    union all
    select cohort_month, 2, 'payment', paid_orders, created_orders, created_orders, cohort_month in (first_cohort_month, last_cohort_month)
    from cohorts
    union all
    select cohort_month, 3, 'fulfilled', fulfilled_orders, paid_orders, created_orders, cohort_month in (first_cohort_month, last_cohort_month)
    from cohorts

)

select
    steps.cohort_month,
    steps.step_order,
    steps.step,
    steps.orders_reached,
    steps.previous_step_orders,
    steps.created_orders,
    {{ safe_ratio('steps.orders_reached', 'steps.previous_step_orders') }} as step_conversion_rate,
    {{ safe_ratio('steps.orders_reached', 'steps.created_orders') }} as cumulative_conversion_rate,
    steps.is_partial_month
from steps
