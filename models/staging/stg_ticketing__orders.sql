-- One row per order. The ticketing extract occasionally lands the same order twice;
-- we keep one copy here and let the source-level unique test (severity: warn) record it.
with source as (
    select * from {{ source('raw', 'ticket_orders') }}
),

typed as (
    select
        upper(trim(order_id))                       as order_id,
        upper(trim(game_id))                        as game_id,
        upper(trim(fan_id))                         as fan_id,
        try_cast(order_ts as timestamp)             as ordered_at,
        lower(trim(sales_channel))                  as sales_channel,
        upper(trim(section_tier))                   as section_tier,
        try_cast(quantity as integer)               as quantity,
        try_cast(unit_price as decimal(10, 2))      as unit_price,
        coalesce(try_cast(discount_amount as decimal(10, 2)), 0) as discount_amount,
        upper(trim(order_status))                   as order_status,
        coalesce(try_cast(tickets_scanned as integer), 0) as tickets_scanned
    from source
)

select
    *,
    cast(quantity * unit_price as decimal(12, 2))                     as gross_amount,
    cast(quantity * unit_price - discount_amount as decimal(12, 2))   as net_amount
from typed
qualify row_number() over (partition by order_id order by ordered_at) = 1
