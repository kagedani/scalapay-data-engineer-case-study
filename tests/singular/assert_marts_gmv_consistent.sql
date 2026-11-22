-- Fulfilled GMV and lost GMV agree across the marts and with the star layer:
-- the marts slice the same orders in different ways and must not lose or
-- double count any of them.

with star as (

    select
        {{ gmv() }} as gmv,
        {{ gmv('dropped') }} as lost_gmv
    from {{ ref('fct_orders') }} as orders
    inner join {{ ref('dim_products') }} as products
        on orders.product_id = products.product_id

),

marts as (

    select 'category_performance' as mart, sum(gmv) as gmv, sum(lost_gmv) as lost_gmv
    from {{ ref('category_performance') }}
    union all
    select 'tier_behavior', sum(gmv), null
    from {{ ref('tier_behavior') }}
    union all
    select 'customer_lifetime_value', sum(historical_clv), null
    from {{ ref('customer_lifetime_value') }}
    union all
    select 'customer_subscription_periods', sum(gmv), null
    from {{ ref('customer_subscription_periods') }}
    union all
    select 'dropoff_analysis', null, sum(lost_gmv)
    from {{ ref('dropoff_analysis') }}

)

select
    marts.mart,
    marts.gmv,
    marts.lost_gmv,
    star.gmv as star_gmv,
    star.lost_gmv as star_lost_gmv
from marts
cross join star
where marts.gmv <> star.gmv
    or marts.lost_gmv <> star.lost_gmv
