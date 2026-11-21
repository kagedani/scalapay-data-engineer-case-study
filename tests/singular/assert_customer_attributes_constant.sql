-- Country and email never change for a customer.
-- dim_customers is type 1 on these columns and relies on this.

select
    customer_id,
    count(distinct country) as country_versions,
    count(distinct email) as email_versions
from {{ ref('stg_customers') }}
group by customer_id
having count(distinct country) > 1
    or count(distinct email) > 1
