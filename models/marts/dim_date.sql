with spine as (
    {{ dbt.date_spine('day', "cast('2018-01-01' as date)", "cast('2026-12-31' as date)") }}
)

select
    cast(date_day as date)                          as date_day,
    extract(year  from date_day)                    as year,
    extract(month from date_day)                    as month,
    extract(dow   from date_day)                    as day_of_week,   -- 0 = Sunday
    case extract(dow from date_day)
        when 0 then 'Sun' when 1 then 'Mon' when 2 then 'Tue' when 3 then 'Wed'
        when 4 then 'Thu' when 5 then 'Fri' else 'Sat' end as day_name,
    extract(dow from date_day) in (0, 5, 6)         as is_weekend,    -- Fri–Sun game nights
    case when extract(month from date_day) between 6 and 11
         then extract(year from date_day) end       as football_season
from spine
