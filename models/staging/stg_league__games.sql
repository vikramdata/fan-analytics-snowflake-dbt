with source as (
    select * from {{ source('raw', 'games') }}
)

select
    upper(trim(game_id))                as game_id,
    try_cast(season as integer)         as season,
    try_cast(week as integer)           as week,
    try_cast(game_date as date)         as game_date,
    trim(kickoff_local)                 as kickoff_local,
    upper(trim(game_type))              as game_type,
    upper(trim(home_team_id))           as home_team_id,
    upper(trim(away_team_id))           as away_team_id,
    upper(trim(venue_id))               as venue_id,
    try_cast(home_score as integer)     as home_score,
    try_cast(away_score as integer)     as away_score
from source
