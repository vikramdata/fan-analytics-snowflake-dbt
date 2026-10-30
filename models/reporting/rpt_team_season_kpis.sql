-- Grain: one team, one season (regular-season home games). Feeds the executive dashboard.
with games as (
    select * from {{ ref('fct_game_attendance') }}
    where game_type = 'REGULAR'
),

game_kpis as (
    select
        home_team_id                                    as team_id,
        season,
        count(*)                                        as home_games,
        sum(capacity)                                   as total_capacity,
        sum(tickets_sold)                               as tickets_sold,
        sum(attendance)                                 as total_attendance,
        avg(attendance)                                 as avg_attendance,
        cast(sum(tickets_sold) as double) / nullif(sum(capacity), 0)        as sell_through_pct,
        1 - cast(sum(attendance) as double) / nullif(sum(tickets_sold), 0)  as no_show_rate,
        sum(net_ticket_revenue)                         as net_ticket_revenue,
        sum(net_ticket_revenue) / nullif(sum(attendance), 0) as net_revenue_per_attendee
    from games
    group by home_team_id, season
),

buyer_games as (
    select g.home_team_id as team_id, g.season, o.fan_id, count(distinct o.game_id) as games_bought
    from {{ ref('fct_ticket_orders') }} o
    inner join games g on o.game_id = g.game_id
    where o.order_status = 'COMPLETED'
    group by g.home_team_id, g.season, o.fan_id
),

buyers as (
    select
        team_id,
        season,
        count(*)                                                      as buyers,
        cast(sum(case when games_bought >= 2 then 1 else 0 end) as double) / nullif(count(*), 0) as repeat_buyer_rate
    from buyer_games
    group by team_id, season
),

engaged as (
    select f.favourite_team_id as team_id, extract(year from e.event_date) as season,
           count(distinct e.fan_id) as engaged_fans
    from {{ ref('fct_fan_engagement_daily') }} e
    inner join {{ ref('stg_crm__fans') }} f on e.fan_id = f.fan_id
    group by f.favourite_team_id, extract(year from e.event_date)
)

select
    k.*,
    t.team_name,
    t.division,
    b.buyers,
    b.repeat_buyer_rate,
    e.engaged_fans,
    k.avg_attendance / nullif(lag(k.avg_attendance) over (partition by k.team_id order by k.season), 0) - 1
        as avg_attendance_yoy_pct
from game_kpis k
left join {{ ref('dim_teams') }} t on k.team_id = t.team_id
left join buyers  b on k.team_id = b.team_id and k.season = b.season
left join engaged e on k.team_id = e.team_id and k.season = e.season
