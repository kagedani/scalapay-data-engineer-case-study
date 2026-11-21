-- One row per shipping company, cleaned.

with source as (

    select * from {{ source('raw_data', 'shipping_company') }}

),

renamed as (

    select
        id::integer as shipping_company_id,
        trim(name)::text as shipping_company_name
    from source

)

select distinct
    shipping_company_id,
    shipping_company_name
from renamed
