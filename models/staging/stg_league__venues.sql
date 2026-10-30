with source as (
    select * from {{ source('raw', 'venues') }}
)

select
    upper(trim(venue_id))           as venue_id,
    trim(venue_name)                as venue_name,
    trim(city)                      as city,
    upper(trim(province))           as province,
    try_cast(capacity as integer)   as capacity
from source
