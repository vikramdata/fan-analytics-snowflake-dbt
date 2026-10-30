# Power BI dashboard

## Connect
1. Power BI Desktop → **Get data → Snowflake**.
2. Server: `<account>.snowflakecomputing.com`, Warehouse: `TRANSFORM_WH`, role: `REPORTER` (read-only).
3. Import from `FAN_ANALYTICS.MARTS`: `dim_date`, `dim_teams`, `dim_games`, `dim_fans`,
   `fct_game_attendance`, `fct_ticket_orders`, `fct_fan_engagement_daily`, `dq_quarantine_ticket_orders`;
   from `FAN_ANALYTICS.REPORTING`: `rpt_team_season_kpis`, `rpt_kpi_anomalies`
   (and `ai_kpi_narratives` if you built the Cortex model).

Working locally without Snowflake? Export the DuckDB tables to CSV and import those instead:
`python -c "import duckdb; c=duckdb.connect('data/fan_analytics.duckdb'); [c.sql(f\"copy marts.{t} to 'powerbi/{t}.csv'\") for t in ['dim_date','dim_teams','dim_games','dim_fans','fct_game_attendance','fct_ticket_orders']]"`

## Model (star schema)
| From | To | Cardinality |
|---|---|---|
| `fct_game_attendance[GAME_DATE]` | `dim_date[DATE_DAY]` | many-to-one |
| `fct_game_attendance[GAME_ID]` | `dim_games[GAME_ID]` | one-to-one |
| `fct_game_attendance[HOME_TEAM_ID]` | `dim_teams[TEAM_ID]` | many-to-one |
| `fct_ticket_orders[GAME_ID]` | `dim_games[GAME_ID]` | many-to-one |
| `fct_ticket_orders[FAN_ID]` | `dim_fans[FAN_ID]` | many-to-one |
| `fct_fan_engagement_daily[FAN_ID]` | `dim_fans[FAN_ID]` | many-to-one |
| `fct_fan_engagement_daily[EVENT_DATE]` | `dim_date[DATE_DAY]` | many-to-one |

Mark `dim_date` as the date table. Paste the measures from `measures.dax`.

## Pages
1. **Executive overview** — KPI cards (Net Ticket Revenue, Attendance, Sell-Through %, Net Revenue YoY %),
   revenue by season, sell-through by team.
2. **Game demand** — attendance vs capacity per game, no-show rate, anomaly table from `rpt_kpi_anomalies`
   with the AI narrative column.
3. **Fans** — fan segments (`dim_fans[FAN_SEGMENT]`), buyers vs engaged fans by team, channel mix.
4. **Data health** — quarantined orders by issue, latest dbt test results.

Save screenshots of each page to `docs/img/` for the README.
