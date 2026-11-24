-- Fulfilled GMV, lost GMV and GMV lost in shipping agree across the marts and
-- with the star layer:
-- the marts slice the same orders in different ways and must not lose or
-- double count any of them.

with star as (

    select
        {{ gmv() }} as gmv,
        {{ gmv('dropped') }} as lost_gmv,
        {{ gmv('dropped', condition="orders.dropoff_reason = 'lost_in_shipping'") }} as lost_in_shipping_gmv
    from {{ ref('fct_orders') }} as orders
    inner join {{ ref('dim_products') }} as products
        on orders.product_id = products.product_id

),

marts as (

    select 'category_performance' as mart, sum(gmv) as gmv, sum(lost_gmv) as lost_gmv, null::numeric as lost_in_shipping_gmv
    from {{ ref('category_performance') }}
    union all
    select 'tier_behavior', sum(gmv), null, null
    from {{ ref('tier_behavior') }}
    union all
    select 'customer_lifetime_value', sum(historical_clv), null, null
    from {{ ref('customer_lifetime_value') }}
    union all
    select 'customer_subscription_periods', sum(gmv), null, null
    from {{ ref('customer_subscription_periods') }}
    union all
    select 'dropoff_analysis', null, sum(lost_gmv), sum(lost_gmv) filter (where dropoff_reason = 'lost_in_shipping')
    from {{ ref('dropoff_analysis') }}
    union all
    select 'shipping_performance', null, null, sum(lost_in_shipping_gmv)
    from {{ ref('shipping_performance') }}

)

select
    marts.mart,
    marts.gmv,
    marts.lost_gmv,
    marts.lost_in_shipping_gmv,
    star.gmv as star_gmv,
    star.lost_gmv as star_lost_gmv,
    star.lost_in_shipping_gmv as star_lost_in_shipping_gmv
from marts
cross join star
where marts.gmv <> star.gmv
    or marts.lost_gmv <> star.lost_gmv
    or marts.lost_in_shipping_gmv <> star.lost_in_shipping_gmv
