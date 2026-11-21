-- SCD2 of the subscription tier only (Kimball mini-dimension): one row per
-- customer and tier period, half-open interval [valid_from, valid_to).
--
-- Built from the event history already present in the source, so dbt snapshots
-- are not needed: a snapshot would only record what changed between our runs.

with customer_events as (

    select
        customer_id,
        subs_tier,
        updated_at
    from {{ ref('stg_customers') }}

),

with_previous_tier as (

    select
        *,
        lag(subs_tier) over (partition by customer_id order by updated_at) as previous_tier
    from customer_events

),

-- An event repeating the current tier does not open a new period.
tier_changes as (

    select
        customer_id,
        subs_tier,
        updated_at as valid_from
    from with_previous_tier
    where previous_tier is null or previous_tier <> subs_tier

),

periods as (

    select
        customer_id,
        subs_tier,
        valid_from,
        coalesce(
            lead(valid_from) over (partition by customer_id order by valid_from),
            '9999-12-31'::timestamp
        ) as valid_to
    from tier_changes

)

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'valid_from']) }} as customer_subscription_sk,
    customer_id,
    subs_tier,
    valid_from,
    valid_to,
    valid_to = '9999-12-31'::timestamp as is_current,
    {{ audit_run_ts() }} as insert_ts,
    {{ audit_run_ts() }} as last_update_ts
from periods
