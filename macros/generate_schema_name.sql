{#-
  Use clean schema names (STAGING, MARTS, REPORTING ...) instead of dbt's default
  "<target_schema>_<custom_schema>" so the warehouse layout matches the architecture doc.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
