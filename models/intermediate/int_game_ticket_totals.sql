-- Ticket totals per game from valid, completed orders.
select
    game_id,
    sum(quantity)                                   as tickets_sold,
    sum(tickets_scanned)                            as tickets_scanned,
    count(*)                                        as orders,
    count(distinct fan_id)                          as buyers,
    sum(gross_amount)                               as gross_ticket_revenue,
    sum(net_amount)                                 as net_ticket_revenue,
    sum(case when section_tier = 'PREMIUM' then net_amount else 0 end) as premium_revenue,
    sum(case when sales_channel = 'season_ticket' then quantity else 0 end) as season_ticket_seats
from {{ ref('int_ticket_orders__validated') }}
where dq_issue is null
  and order_status = 'COMPLETED'
group by game_id
