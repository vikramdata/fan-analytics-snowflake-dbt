{% docs __overview__ %}
# Fan & Ticketing Analytics

Governed analytics layer for a professional football league: ticketing, attendance and
fan engagement modeled in **Snowflake + dbt** and served to **Power BI**.

* **staging** — one model per source table: typing, cleaning, de-duplication. Views.
* **intermediate** — business rules (data quality validation, per-game totals). Views.
* **marts** — dimensional model (dims + facts) and the DQ quarantine. Tables.
* **reporting** — KPI tables for dashboards and the anomaly feed for the AI insights layer.

Every KPI below is defined once here and reused by the marts, the semantic layer and Power BI.
All data is synthetic except team names and cities.
{% enddocs %}

{% docs gross_ticket_revenue %}
**Gross ticket revenue** — quantity × unit price, before discounts, CAD.
Only valid, completed orders count in the marts (refunds excluded).
{% enddocs %}

{% docs net_ticket_revenue %}
**Net ticket revenue** — gross ticket revenue minus discounts, CAD. The league's headline revenue KPI.
{% enddocs %}

{% docs sell_through_pct %}
**Sell-through %** — tickets sold ÷ venue capacity for a game. Measures demand.
Can exceed 100% only if capacity data is wrong; a test enforces ≤ 100%.
{% enddocs %}

{% docs attendance %}
**Attendance (scanned)** — tickets scanned at the gate. Differs from tickets sold by no-shows.
{% enddocs %}

{% docs no_show_rate %}
**No-show rate** — 1 − tickets scanned ÷ tickets sold. High values signal weak engagement
even when sales look healthy (e.g. bad weather, unused season tickets).
{% enddocs %}

{% docs revenue_per_attendee %}
**Net revenue per attendee** — net ticket revenue ÷ attendance (scanned).
{% enddocs %}

{% docs engaged_fan %}
**Engaged fan** — a fan with at least one app or web event in the period.
{% enddocs %}

{% docs repeat_buyer_rate %}
**Repeat buyer rate** — share of a season's buyers who bought for 2+ different games that season.
{% enddocs %}
