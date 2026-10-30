-- Regular-season games whose attendance is unusual for that home team and season
-- (|z-score| >= var('anomaly_z_threshold')). This is the governed input to the AI insights layer:
-- the AI only explains rows from this table, it never computes numbers itself.
with games as (
    select a.*, g.matchup, g.home_team_name
    from {{ ref('fct_game_attendance') }} a
    inner join {{ ref('dim_games') }} g on a.game_id = g.game_id
    where a.game_type = 'REGULAR'
),

scored as (
    select
        *,
        avg(attendance)        over (partition by home_team_id, season) as team_season_avg_attendance,
        stddev_samp(attendance) over (partition by home_team_id, season) as team_season_std_attendance
    from games
)

select
    game_id,
    season,
    game_date,
    home_team_id,
    home_team_name,
    matchup,
    capacity,
    tickets_sold,
    attendance,
    round(team_season_avg_attendance, 0)                                  as team_season_avg_attendance,
    round((attendance - team_season_avg_attendance) / nullif(team_season_std_attendance, 0), 2) as attendance_z_score,
    case when attendance < team_season_avg_attendance then 'BELOW' else 'ABOVE' end as direction,
    round(sell_through_pct, 3)                                            as sell_through_pct,
    round(no_show_rate, 3)                                                as no_show_rate,
    net_ticket_revenue
from scored
where abs((attendance - team_season_avg_attendance) / nullif(team_season_std_attendance, 0))
      >= {{ var('anomaly_z_threshold') }}
