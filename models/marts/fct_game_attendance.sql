-- Grain: one game. Capacity comes from the venue the game was played at (Grey Cup = host venue).
with games as (
    select * from {{ ref('dim_games') }}
),

venues as (
    select venue_id, capacity from {{ ref('stg_league__venues') }}
),

totals as (
    select * from {{ ref('int_game_ticket_totals') }}
)

select
    g.game_id,
    g.season,
    g.game_date,
    g.game_type,
    g.home_team_id,
    g.away_team_id,
    g.venue_id,
    v.capacity,
    coalesce(t.tickets_sold, 0)                     as tickets_sold,
    coalesce(t.tickets_scanned, 0)                  as attendance,
    coalesce(t.buyers, 0)                           as buyers,
    coalesce(t.gross_ticket_revenue, 0)             as gross_ticket_revenue,
    coalesce(t.net_ticket_revenue, 0)               as net_ticket_revenue,
    coalesce(t.premium_revenue, 0)                  as premium_revenue,
    coalesce(t.season_ticket_seats, 0)              as season_ticket_seats,
    cast(coalesce(t.tickets_sold, 0) as double) / nullif(v.capacity, 0)              as sell_through_pct,
    1 - cast(coalesce(t.tickets_scanned, 0) as double) / nullif(t.tickets_sold, 0)   as no_show_rate,
    coalesce(t.net_ticket_revenue, 0) / nullif(t.tickets_scanned, 0)                 as net_revenue_per_attendee
from games g
left join venues v on g.venue_id = v.venue_id
left join totals t on g.game_id  = t.game_id
