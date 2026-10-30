-- Reconciliation: net revenue in the game fact must equal the sum of completed orders (to the cent).
with orders as (
    select sum(net_amount) as revenue
    from {{ ref('fct_ticket_orders') }}
    where order_status = 'COMPLETED'
),
games as (
    select sum(net_ticket_revenue) as revenue from {{ ref('fct_game_attendance') }}
)
select orders.revenue as order_revenue, games.revenue as game_revenue
from orders cross join games
where abs(orders.revenue - games.revenue) > 0.01
