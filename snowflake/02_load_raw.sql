-- ============================================================================
-- 02_load_raw.sql — land the CSVs in FAN_ANALYTICS.RAW
-- RAW is a landing zone: every column is VARCHAR and typing happens in dbt staging,
-- so a malformed value never breaks a load (it shows up in dbt tests instead).
--
-- Files get to the stage either with:
--   python scripts/load_to_snowflake.py      (PUT + this COPY logic, recommended)
-- or in SnowSQL:  PUT file://data/raw/*.csv @raw.landing_stage AUTO_COMPRESS=TRUE;
-- ============================================================================
use role loader;
use warehouse transform_wh;
use schema fan_analytics.raw;

create file format if not exists csv_landing
  type = csv skip_header = 1 field_optionally_enclosed_by = '"'
  null_if = ('', 'NULL') empty_field_as_null = true;

create stage if not exists landing_stage file_format = csv_landing;

create table if not exists teams (
  team_id varchar, team_name varchar, city varchar, province varchar, division varchar,
  _loaded_at timestamp_ltz default current_timestamp(), _source_file varchar);

create table if not exists venues (
  venue_id varchar, venue_name varchar, city varchar, province varchar, capacity varchar,
  _loaded_at timestamp_ltz default current_timestamp(), _source_file varchar);

create table if not exists games (
  game_id varchar, season varchar, week varchar, game_date varchar, kickoff_local varchar,
  game_type varchar, home_team_id varchar, away_team_id varchar, venue_id varchar,
  home_score varchar, away_score varchar,
  _loaded_at timestamp_ltz default current_timestamp(), _source_file varchar);

create table if not exists fans (
  fan_id varchar, signup_date varchar, home_province varchar, favourite_team_id varchar,
  email_opt_in varchar, acquisition_channel varchar,
  _loaded_at timestamp_ltz default current_timestamp(), _source_file varchar);

create table if not exists ticket_orders (
  order_id varchar, game_id varchar, fan_id varchar, order_ts varchar, sales_channel varchar,
  section_tier varchar, quantity varchar, unit_price varchar, discount_amount varchar,
  order_status varchar, tickets_scanned varchar,
  _loaded_at timestamp_ltz default current_timestamp(), _source_file varchar);

create table if not exists engagement_events (
  event_id varchar, fan_id varchar, event_ts varchar, platform varchar, event_type varchar,
  team_id varchar, session_seconds varchar,
  _loaded_at timestamp_ltz default current_timestamp(), _source_file varchar);

-- Full refresh of the landing tables (the generator re-creates whole files)
truncate table teams; truncate table venues; truncate table games;
truncate table fans; truncate table ticket_orders; truncate table engagement_events;

copy into teams (team_id, team_name, city, province, division, _source_file)
  from (select $1, $2, $3, $4, $5, metadata$filename from @landing_stage/teams.csv.gz);
copy into venues (venue_id, venue_name, city, province, capacity, _source_file)
  from (select $1, $2, $3, $4, $5, metadata$filename from @landing_stage/venues.csv.gz);
copy into games (game_id, season, week, game_date, kickoff_local, game_type, home_team_id,
                 away_team_id, venue_id, home_score, away_score, _source_file)
  from (select $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, metadata$filename
        from @landing_stage/games.csv.gz);
copy into fans (fan_id, signup_date, home_province, favourite_team_id, email_opt_in,
                acquisition_channel, _source_file)
  from (select $1, $2, $3, $4, $5, $6, metadata$filename from @landing_stage/fans.csv.gz);
copy into ticket_orders (order_id, game_id, fan_id, order_ts, sales_channel, section_tier,
                         quantity, unit_price, discount_amount, order_status, tickets_scanned,
                         _source_file)
  from (select $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, metadata$filename
        from @landing_stage/ticket_orders.csv.gz);
copy into engagement_events (event_id, fan_id, event_ts, platform, event_type, team_id,
                             session_seconds, _source_file)
  from (select $1, $2, $3, $4, $5, $6, $7, metadata$filename
        from @landing_stage/engagement_events.csv.gz);

-- Row counts after load
select 'ticket_orders' as tbl, count(*) from ticket_orders
union all select 'engagement_events', count(*) from engagement_events
union all select 'fans', count(*) from fans
union all select 'games', count(*) from games;
