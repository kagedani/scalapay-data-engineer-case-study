-- One row per product, cleaned.
-- Products carry no timestamp, so conflicting duplicates cannot be resolved:
-- exact duplicates are collapsed, anything else fails the unique test on product_id.
--
-- Category cleaning is a code rule, not a mapping table: the source only has
-- spelling noise (casing, spacing around '&'), no real synonyms.
-- Same convention as country: upper-cased, inner spaces as '_'.
--   'electronics'   -> 'ELECTRONICS'
--   'Home&Garden'   -> 'HOME_&_GARDEN'
--   'Home & Garden' -> 'HOME_&_GARDEN'
--   null / blank    -> 'UNDEFINED'
-- Values the rule does not cover are caught by accepted_values (severity error).

with source as (

    select * from {{ source('raw_data', 'products') }}

),

renamed as (

    select
        id::integer as product_id,
        price::numeric(10, 2) as price,
        coalesce(
            upper(
                regexp_replace(
                    -- give '&' exactly one space per side, then spaces -> '_'
                    regexp_replace(nullif(trim(category), ''), '\s*&\s*', ' & ', 'g'),
                    '\s+', '_', 'g'
                )
            ),
            'UNDEFINED'
        )::text as category
    from source

)

select distinct
    product_id,
    price,
    category
from renamed
