# Development standards

These are the team standards for this project; a pull request that breaks them should not merge.

## Layers and naming
| Layer | Prefix | Materialization | Rules |
|---|---|---|---|
| staging | `stg_<source>__<entity>` | view | 1:1 with a source table. Rename, cast, clean, de-duplicate. No joins. |
| intermediate | `int_<entity>__<verb>` | view | Business rules and reusable joins. Not exposed to BI. |
| marts | `dim_` / `fct_` | table | Star schema. Grain stated in the first comment line. |
| reporting | `rpt_` | table | KPI tables for dashboards and AI. |

## SQL style
- Lowercase keywords, one column per line, trailing commas, CTEs over subqueries.
- `select *` only in the first CTE that reads a `ref` / `source`.
- Portable SQL: the project must build on both DuckDB (dev/CI) and Snowflake (prod).

## Every new model needs
- A description and its grain in YAML.
- `unique` + `not_null` on its primary key; `relationships` on foreign keys.
- KPI columns documented with the shared `{{ doc() }}` block, never a new definition.

## Pull request checklist
- [ ] `dbt build` passes locally (`make build`)
- [ ] New KPI or changed definition → `docs/kpi_dictionary.md` and `models/docs.md` updated
- [ ] No credentials or data files committed
- [ ] Reviewer from the owning business team for KPI changes
