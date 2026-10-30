with games as (
    select * from {{ ref('stg_league__games') }}
),

teams as (
    select team_id, team_name from {{ ref('stg_league__teams') }}
)

select
    g.game_id,
    g.season,
    g.week,
    g.game_date,
    g.kickoff_local,
    g.game_type,
    g.home_team_id,
    home.team_name                                  as home_team_name,
    g.away_team_id,
    away.team_name                                  as away_team_name,
    home.team_name || ' vs ' || away.team_name      as matchup,
    g.venue_id,
    g.home_score,
    g.away_score,
    case when g.home_score > g.away_score then g.home_team_id
         when g.away_score > g.home_score then g.away_team_id end as winning_team_id,
    abs(g.home_score - g.away_score)                as point_margin
from games g
left join teams home on g.home_team_id = home.team_id
left join teams away on g.away_team_id = away.team_id
