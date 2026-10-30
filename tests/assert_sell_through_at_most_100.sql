-- A game cannot sell more tickets than the venue holds; if it does, capacity or orders are wrong.
select game_id, capacity, tickets_sold, sell_through_pct
from {{ ref('fct_game_attendance') }}
where sell_through_pct > 1
