-- Applies business data quality rules to every order and labels the first failing rule.
-- Valid orders flow to the marts; invalid ones go to dq_quarantine_ticket_orders for triage.
with orders as (
    select * from {{ ref('stg_ticketing__orders') }}
),

games as (
    select game_id, game_date from {{ ref('stg_league__games') }}
),

fans as (
    select fan_id from {{ ref('stg_crm__fans') }}
)

select
    orders.*,
    games.game_date,
    case
        when games.game_id is null              then 'UNKNOWN_GAME'
        when fans.fan_id is null                then 'UNKNOWN_FAN'
        when orders.unit_price is null          then 'MISSING_PRICE'
        when orders.unit_price < 0              then 'NEGATIVE_PRICE'
        when orders.quantity is null
          or orders.quantity <= 0               then 'INVALID_QUANTITY'
        when orders.tickets_scanned > orders.quantity then 'SCANS_EXCEED_QUANTITY'
        when cast(orders.ordered_at as date) > games.game_date then 'ORDERED_AFTER_GAME'
    end                                         as dq_issue
from orders
left join games on orders.game_id = games.game_id
left join fans  on orders.fan_id  = fans.fan_id
