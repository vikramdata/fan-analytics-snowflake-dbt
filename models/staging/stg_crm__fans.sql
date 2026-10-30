with source as (
    select * from {{ source('raw', 'fans') }}
)

select
    upper(trim(fan_id))                     as fan_id,
    try_cast(signup_date as date)           as signup_date,
    upper(trim(home_province))              as home_province,
    upper(trim(favourite_team_id))          as favourite_team_id,
    coalesce(try_cast(email_opt_in as boolean), false) as is_email_opt_in,
    lower(trim(acquisition_channel))        as acquisition_channel
from source
