{{ config(enabled = target.type == 'snowflake') }}
-- Snowflake only: Cortex writes a short plain-English note for each attendance anomaly.
-- Responsible-AI guardrails:
--   * the model only receives governed numbers from rpt_kpi_anomalies (it never queries raw data)
--   * the prompt forbids inventing causes or figures; it may only suggest what to check
--   * source figures stay next to the narrative so every sentence can be verified
with anomalies as (
    select * from {{ ref('rpt_kpi_anomalies') }}
)

select
    game_id,
    matchup,
    game_date,
    attendance,
    team_season_avg_attendance,
    attendance_z_score,
    no_show_rate,
    snowflake.cortex.complete(
        '{{ var("cortex_model") }}',
        'You are a sports business analyst writing for league executives. '
        || 'Using ONLY the figures below, write 2 sentences: what happened, and one thing the '
        || 'business team should check (e.g. weather, promotions, opponent, kickoff time). '
        || 'Do not invent causes or numbers. '
        || 'Game: ' || matchup || ' on ' || to_varchar(game_date)
        || '. Attendance: ' || to_varchar(attendance)
        || ' vs team season average ' || to_varchar(team_season_avg_attendance)
        || ' (z-score ' || to_varchar(attendance_z_score) || ', ' || direction || ' normal)'
        || '. Sell-through: ' || to_varchar(round(sell_through_pct * 100, 1)) || '%'
        || '. No-show rate: ' || to_varchar(round(no_show_rate * 100, 1)) || '%.'
    )                                   as ai_narrative,
    '{{ var("cortex_model") }}'         as ai_model,
    current_timestamp()                 as generated_at
from anomalies
