select game_id, tickets_sold, attendance
from {{ ref('fct_game_attendance') }}
where attendance > tickets_sold
