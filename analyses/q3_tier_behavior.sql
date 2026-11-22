-- Q3. How do subscription tiers (free, premium, enterprise) impact customer behavior?
-- Tier at order time (point-in-time). Per-30-day metrics use comparable periods only.

select
    subs_tier,
    ordering_customers,
    orders,
    payment_rate,
    fulfillment_rate,
    overall_conversion_rate,
    avg_fulfilled_order_value,
    comparable_periods,
    orders_per_30_days,
    gmv_per_30_days
from {{ ref('tier_behavior') }}
order by tier_rank
