-- Every order matches exactly one subscription period through the point-in-time
-- join used by the marts (none would drop the order, two would double count it).

with matches as (

    select
        orders.order_id,
        count(subscriptions.customer_subscription_sk) as matched_periods
    from {{ ref('fct_orders') }} as orders
    {{ join_subscription_at_order_time('orders', 'subscriptions', join_type='left') }}
    group by orders.order_id

)

select * from matches where matched_periods <> 1
