with source as (
    select * from {{ source('raw', 'teams') }}
)

select
    upper(trim(team_id))        as team_id,
    trim(team_name)             as team_name,
    trim(city)                  as city,
    upper(trim(province))       as province,
    case upper(trim(division)) when 'WEST' then 'West' when 'EAST' then 'East' end as division
from source
