-- Engagement events from fan_ids the CRM doesn't know. They are excluded from the engagement fact;
-- this test surfaces them (warn) so the app-to-CRM identity sync can be investigated.
{{ config(severity = 'warn') }}
select e.event_id, e.fan_id, e.event_at, e.platform
from {{ ref('stg_digital__events') }} e
left join {{ ref('stg_crm__fans') }} f on e.fan_id = f.fan_id
where f.fan_id is null
