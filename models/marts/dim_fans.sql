with fans as (
    select * from {{ ref('stg_crm__fans') }}
),

purchases as (
    select
        fan_id,
        min(cast(ordered_at as date))   as first_purchase_date,
        max(cast(ordered_at as date))   as last_purchase_date,
        count(*)                        as lifetime_orders,
        sum(net_amount)                 as lifetime_net_revenue
    from {{ ref('fct_ticket_orders') }}
    where order_status = 'COMPLETED'
    group by fan_id
),

engagement as (
    select fan_id, max(event_date) as last_engaged_date, sum(events) as lifetime_events
    from {{ ref('fct_fan_engagement_daily') }}
    group by fan_id
)

select
    f.*,
    p.first_purchase_date,
    p.last_purchase_date,
    coalesce(p.lifetime_orders, 0)          as lifetime_orders,
    coalesce(p.lifetime_net_revenue, 0)     as lifetime_net_revenue,
    e.last_engaged_date,
    coalesce(e.lifetime_events, 0)          as lifetime_events,
    case
        when p.fan_id is not null and e.fan_id is not null then 'Buyer + Digital'
        when p.fan_id is not null                          then 'Buyer only'
        when e.fan_id is not null                          then 'Digital only'
        else 'Dormant'
    end                                     as fan_segment
from fans f
left join purchases  p on f.fan_id = p.fan_id
left join engagement e on f.fan_id = e.fan_id
