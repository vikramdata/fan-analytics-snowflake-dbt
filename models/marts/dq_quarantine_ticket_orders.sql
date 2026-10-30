-- Orders that failed a data quality rule, kept for triage instead of silently dropped.
select
    dq_issue,
    order_id,
    game_id,
    fan_id,
    ordered_at,
    quantity,
    unit_price,
    tickets_scanned,
    current_timestamp as quarantined_at
from {{ ref('int_ticket_orders__validated') }}
where dq_issue is not null
