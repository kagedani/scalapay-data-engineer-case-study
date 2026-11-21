-- One row per customer event, cleaned and deduplicated.
-- Dedup rule (same for every staging model with an event key):
--   * identical rows after normalisation are collapsed (distinct);
--   * conflicting versions of the same event keep the latest updated_at;
--   * conflicting versions with the same updated_at both survive and make the
--     unique test on customer_event_id fail: no business rule can pick one.

with source as (

    select * from {{ source('raw_data', 'customers') }}

),

renamed as (

    select
        event_id::integer as customer_event_id,
        customer_id::integer as customer_id,
        -- Defensive normalisation, even where today's data is clean:
        -- country upper-cased with inner spaces as '_' (USA, UK, GERMANY, NEW_ZEALAND);
        -- tier lower-cased with every whitespace removed (' Free ' -> 'free').
        upper(regexp_replace(trim(country), '\s+', '_', 'g'))::text as country,
        lower(trim(email))::text as email,
        lower(regexp_replace(subs_tier, '\s', '', 'g'))::text as subs_tier,
        updated_at::timestamp as updated_at
    from source

),

deduplicated as (

    select distinct * from renamed

),

latest_version as (

    select
        *,
        max(updated_at) over (partition by customer_event_id) as latest_updated_at
    from deduplicated

)

select
    customer_event_id,
    customer_id,
    country,
    email,
    subs_tier,
    updated_at
from latest_version
where updated_at = latest_updated_at
