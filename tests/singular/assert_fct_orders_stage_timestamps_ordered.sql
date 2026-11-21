-- Stages are reached in order: no stage without the previous one,
-- and timestamps never go backwards.

select *
from {{ ref('fct_orders') }}
where (fulfilled_at is not null and paid_at is null)
    or paid_at < created_at
    or fulfilled_at < paid_at
