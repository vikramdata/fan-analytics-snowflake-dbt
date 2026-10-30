-- ============================================================================
-- 01_setup.sql — one-time Snowflake setup (run as ACCOUNTADMIN in a Snowsight worksheet)
-- Creates: cost guardrail, warehouse, database + schemas, and least-privilege roles
--   LOADER      lands raw files into RAW
--   TRANSFORMER dbt: reads RAW, builds STAGING / INTERMEDIATE / MARTS / REPORTING / DQ_AUDIT
--   REPORTER    Power BI and analysts: read-only on MARTS and REPORTING
-- ============================================================================
use role accountadmin;

-- Cost guardrail: suspend the warehouse before the trial credits run out
create resource monitor if not exists fan_analytics_monitor
  with credit_quota = 20 frequency = monthly start_timestamp = immediately
  triggers on 80 percent do notify
           on 100 percent do suspend;

create warehouse if not exists transform_wh
  warehouse_size = xsmall auto_suspend = 60 auto_resume = true initially_suspended = true
  resource_monitor = fan_analytics_monitor
  comment = 'dbt transformations, loading and BI queries';

create database if not exists fan_analytics;
create schema if not exists fan_analytics.raw;
create schema if not exists fan_analytics.staging;
create schema if not exists fan_analytics.intermediate;
create schema if not exists fan_analytics.marts;
create schema if not exists fan_analytics.reporting;
create schema if not exists fan_analytics.dq_audit;

-- Roles ----------------------------------------------------------------------
create role if not exists loader;
create role if not exists transformer;
create role if not exists reporter;
grant role loader to role sysadmin;
grant role transformer to role sysadmin;
grant role reporter to role sysadmin;
set my_user = current_user();
grant role loader      to user identifier($my_user);
grant role transformer to user identifier($my_user);
grant role reporter    to user identifier($my_user);

grant usage on warehouse transform_wh to role loader;
grant usage on warehouse transform_wh to role transformer;
grant usage on warehouse transform_wh to role reporter;
grant usage on database fan_analytics to role loader;
grant usage on database fan_analytics to role transformer;
grant usage on database fan_analytics to role reporter;

-- LOADER: owns RAW
grant all on schema fan_analytics.raw to role loader;

-- TRANSFORMER: read RAW, create everything downstream
grant usage on schema fan_analytics.raw to role transformer;
grant select on all tables in schema fan_analytics.raw to role transformer;
grant select on future tables in schema fan_analytics.raw to role transformer;
grant all on schema fan_analytics.staging      to role transformer;
grant all on schema fan_analytics.intermediate to role transformer;
grant all on schema fan_analytics.marts        to role transformer;
grant all on schema fan_analytics.reporting    to role transformer;
grant all on schema fan_analytics.dq_audit     to role transformer;
grant database role snowflake.cortex_user to role transformer;   -- for ai_kpi_narratives

-- REPORTER: read-only on the governed layers
grant usage on schema fan_analytics.marts     to role reporter;
grant usage on schema fan_analytics.reporting to role reporter;
grant select on future tables in schema fan_analytics.marts     to role reporter;
grant select on future tables in schema fan_analytics.reporting to role reporter;
grant select on all tables in schema fan_analytics.marts        to role reporter;
grant select on all tables in schema fan_analytics.reporting    to role reporter;
