# KPI dictionary

One definition per KPI. dbt implements it, the semantic layer exposes it, Power BI reuses it.
Changing a definition means changing it here **and** in `models/docs.md` in the same pull request.

| KPI | Definition | Grain available | Owner | Source model |
|---|---|---|---|---|
| Net ticket revenue | Σ(quantity × unit price − discounts), completed and valid orders, CAD | order, game, team-season | Ticketing / Finance | `fct_ticket_orders`, `fct_game_attendance` |
| Gross ticket revenue | Σ(quantity × unit price), before discounts | order, game | Finance | `fct_game_attendance` |
| Tickets sold | Σ quantity on completed, valid orders | game, team-season | Ticketing | `fct_game_attendance` |
| Attendance (scanned) | Tickets scanned at the gate | game, team-season | Operations | `fct_game_attendance` |
| Sell-through % | Tickets sold ÷ venue capacity | game, team-season | Ticketing | `fct_game_attendance`, `rpt_team_season_kpis` |
| No-show rate | 1 − attendance ÷ tickets sold | game, team-season | Operations | `fct_game_attendance` |
| Net revenue per attendee | Net ticket revenue ÷ attendance | game, team-season | Finance | `fct_game_attendance` |
| Ticket buyers | Distinct fans with a completed order | game, team-season | Marketing | `rpt_team_season_kpis` |
| Repeat buyer rate | Share of a season's buyers who bought for 2+ games | team-season | Marketing | `rpt_team_season_kpis` |
| Engaged fans | Distinct fans with ≥ 1 app/web event in the period (by favourite team) | day, team-season | Digital | `fct_fan_engagement_daily` |
| Fan segment | Buyer + Digital / Buyer only / Digital only / Dormant | fan | Marketing | `dim_fans` |
| Attendance anomaly | Game with \|z\| ≥ 2 vs the home team's season average | game | Analytics | `rpt_kpi_anomalies` |

## Data quality rules (orders)
| Rule | Action |
|---|---|
| Duplicate `order_id` in the extract | Keep first copy; source test warns with the count |
| Unknown game / unknown fan | Quarantine (`dq_quarantine_ticket_orders`) |
| Negative or missing price, quantity ≤ 0 | Quarantine |
| Scans > tickets on the order, order after game date | Quarantine |
| Quarantine rate > 0.5% of orders | **Build fails** — likely a broken extract, not stray rows |
| Engagement events from fans unknown to the CRM | Excluded from the fact; test warns with the count |
