select
    t.team_id,
    t.team_name,
    t.city,
    t.province,
    t.division,
    v.venue_id      as home_venue_id,
    v.venue_name    as home_venue_name,
    v.capacity      as home_venue_capacity
from {{ ref('stg_league__teams') }} t
left join {{ ref('stg_league__venues') }} v
    on v.venue_id = 'V_' || t.team_id
