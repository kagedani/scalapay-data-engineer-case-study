-- SCD2 periods of a customer must chain with no overlap and no gap:
-- each valid_to equals the next valid_from, the last one is the open period,
-- and every period has positive length.

with periods as (

    select
        customer_id,
        valid_from,
        valid_to,
        lead(valid_from) over (partition by customer_id order by valid_from) as next_valid_from
    from {{ ref('dim_customer_subscriptions') }}

)

select *
from periods
where valid_from >= valid_to
    or (next_valid_from is not null and valid_to <> next_valid_from)
    or (next_valid_from is null and valid_to <> '9999-12-31'::timestamp)
