-- Fail if more than 0.5% of orders are quarantined: that signals a broken extract, not stray bad rows.
with counts as (
    select
        (select count(*) from {{ ref('dq_quarantine_ticket_orders') }}) as quarantined,
        (select count(*) from {{ ref('stg_ticketing__orders') }})       as total
)
select quarantined, total, cast(quarantined as double) / total as quarantine_rate
from counts
where cast(quarantined as double) / total > 0.005
