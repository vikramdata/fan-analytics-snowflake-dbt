-- Grain: one fan, one day, one platform. Events from fans unknown to the CRM are excluded
-- (they are surfaced by the assert_no_unknown_fan_events test instead).
select
    e.fan_id,
    e.event_date,
    e.platform,
    count(*)                                                        as events,
    sum(e.session_seconds)                                          as session_seconds,
    sum(case when e.event_type in ('video_view', 'highlight_view') then 1 else 0 end) as video_events,
    sum(case when e.event_type = 'game_tracker_view' then 1 else 0 end)             as game_tracker_events,
    sum(case when e.event_type = 'store_visit' then 1 else 0 end)                   as store_visits
from {{ ref('stg_digital__events') }} e
inner join {{ ref('stg_crm__fans') }} f on e.fan_id = f.fan_id
group by e.fan_id, e.event_date, e.platform
