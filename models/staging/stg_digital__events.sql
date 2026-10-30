with source as (
    select * from {{ source('raw', 'engagement_events') }}
)

select
    upper(trim(event_id))                       as event_id,
    upper(trim(fan_id))                         as fan_id,
    try_cast(event_ts as timestamp)             as event_at,
    cast(try_cast(event_ts as timestamp) as date) as event_date,
    lower(trim(platform))                       as platform,
    lower(trim(event_type))                     as event_type,
    upper(trim(team_id))                        as team_id,
    coalesce(try_cast(session_seconds as integer), 0) as session_seconds
from source
