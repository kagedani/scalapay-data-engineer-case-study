-- Funnel conversion by monthly cohort (month of order creation) and step.
-- The first and last cohort months may be partial: the data starts and ends mid-month.

with orders as (

    select
        date_trunc('month', created_at)::date as cohort_month,
        paid_at,
        fulfilled_at
    from {{ ref('fct_orders') }}

),

window_bounds as (

    {{ observation_window() }}

),

cohorts as (

    select
        cohort_month,
        count(*) as created_orders,
        count(paid_at) as paid_orders,
        count(fulfilled_at) as fulfilled_orders
    from orders
    group by cohort_month

),

steps as (

    select cohort_month, 1 as step_order, 'created' as step, created_orders as orders_reached, created_orders as previous_step_orders, created_orders
    from cohorts
    union all
    select cohort_month, 2, 'payment', paid_orders, created_orders, created_orders
    from cohorts
    union all
    select cohort_month, 3, 'fulfilled', fulfilled_orders, paid_orders, created_orders
    from cohorts

)

select
    steps.cohort_month,
    steps.step_order,
    steps.step,
    steps.orders_reached,
    steps.previous_step_orders,
    steps.created_orders,
    round(steps.orders_reached::numeric / nullif(steps.previous_step_orders, 0), 4) as step_conversion_rate,
    round(steps.orders_reached::numeric / nullif(steps.created_orders, 0), 4) as cumulative_conversion_rate,
    steps.cohort_month in (
        date_trunc('month', window_bounds.window_start)::date,
        date_trunc('month', window_bounds.window_end)::date
    ) as is_partial_month
from steps
cross join window_bounds
