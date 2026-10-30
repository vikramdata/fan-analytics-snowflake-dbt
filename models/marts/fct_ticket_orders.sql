-- Grain: one valid ticket order. Refunds are kept (order_status) so refund rates can be measured.
select
    order_id,
    game_id,
    fan_id,
    ordered_at,
    cast(ordered_at as date)                        as order_date,
    {{ dbt.datediff('cast(ordered_at as date)', 'game_date', 'day') }} as days_before_game,
    sales_channel,
    section_tier,
    order_status,
    quantity,
    tickets_scanned,
    unit_price,
    discount_amount,
    gross_amount,
    net_amount
from {{ ref('int_ticket_orders__validated') }}
where dq_issue is null
