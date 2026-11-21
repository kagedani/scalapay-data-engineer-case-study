-- Customer value per subscription period (customer x tier period), with exposure
-- inside the observation window so that periods of different length compare.
--
-- Exposure rule: a period overlapping the window is shown, with zero orders if
-- none was placed; a period entirely outside the window is excluded.
-- Periods with at least `min_exposure_days` of exposure are flagged is_comparable:
-- only those feed the tier comparisons and the before/after-upgrade reading.

with window_bounds as (

    {{ observation_window() }}

),

periods as (

    select
        subscriptions.customer_subscription_sk,
        subscriptions.customer_id,
        subscriptions.subs_tier,
        lag(subscriptions.subs_tier) over (
            partition by subscriptions.customer_id order by subscriptions.valid_from
        ) as previous_subs_tier,
        row_number() over (
            partition by subscriptions.customer_id order by subscriptions.valid_from
        ) as period_number,
        subscriptions.valid_from,
        subscriptions.valid_to,
        subscriptions.is_current,
        greatest(subscriptions.valid_from, window_bounds.window_start) as exposure_start,
        least(subscriptions.valid_to, window_bounds.window_end) as exposure_end
    from {{ ref('dim_customer_subscriptions') }} as subscriptions
    cross join window_bounds

),

exposed_periods as (

    select
        *,
        round((extract(epoch from exposure_end - exposure_start) / 86400)::numeric, 2) as exposure_days
    from periods
    where exposure_end > exposure_start

),

period_orders as (

    select
        subscriptions.customer_subscription_sk,
        count(*) as orders,
        count(*) filter (where orders.order_outcome = 'fulfilled') as fulfilled_orders,
        sum(products.price) filter (where orders.order_outcome = 'fulfilled') as gmv
    from {{ ref('fct_orders') }} as orders
    {{ join_subscription_at_order_time('orders', 'subscriptions') }}
    inner join {{ ref('dim_products') }} as products
        on orders.product_id = products.product_id
    group by subscriptions.customer_subscription_sk

)

select
    exposed_periods.customer_subscription_sk,
    exposed_periods.customer_id,
    exposed_periods.period_number,
    exposed_periods.subs_tier,
    exposed_periods.previous_subs_tier,
    case
        when exposed_periods.previous_subs_tier is null then 'initial'
        when {{ tier_rank('exposed_periods.subs_tier') }} > {{ tier_rank('exposed_periods.previous_subs_tier') }} then 'upgrade'
        else 'downgrade'
    end as tier_change,
    exposed_periods.valid_from,
    exposed_periods.valid_to,
    exposed_periods.is_current,
    exposed_periods.exposure_start,
    exposed_periods.exposure_end,
    exposed_periods.exposure_days,
    exposed_periods.exposure_days >= {{ var('min_exposure_days') }} as is_comparable,
    coalesce(period_orders.orders, 0) as orders,
    coalesce(period_orders.fulfilled_orders, 0) as fulfilled_orders,
    coalesce(period_orders.gmv, 0) as gmv,
    round(coalesce(period_orders.orders, 0) * 30 / exposure_days, 4) as orders_per_30_days,
    round(coalesce(period_orders.gmv, 0) * 30 / exposure_days, 2) as gmv_per_30_days
from exposed_periods
left join period_orders
    on exposed_periods.customer_subscription_sk = period_orders.customer_subscription_sk
