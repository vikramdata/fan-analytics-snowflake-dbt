# Architecture

```mermaid
flowchart LR
    subgraph Sources
        T[Ticketing platform<br/>orders]
        C[CRM<br/>fans]
        D[App and web<br/>engagement events]
        L[League operations<br/>teams, venues, games]
    end
    subgraph Snowflake["Snowflake · FAN_ANALYTICS"]
        R[(RAW<br/>all VARCHAR landing)]
        S[STAGING<br/>typed, cleaned, de-duplicated]
        I[INTERMEDIATE<br/>DQ rules, per-game totals]
        M[MARTS<br/>star schema + quarantine]
        P[REPORTING<br/>KPI tables, anomaly feed]
        Q[(DQ_AUDIT<br/>failed test rows)]
    end
    T & C & D & L -->|load_to_snowflake.py<br/>PUT + COPY| R
    R --> S --> I --> M --> P
    S & I & M -.dbt tests.-> Q
    M --> SL[dbt Semantic Layer<br/>metrics]
    M & P --> BI[Power BI<br/>REPORTER role]
    P --> AI[AI insights<br/>Cortex / Claude, verified figures]
    Q --> AI
```

## Decisions
| Decision | Why |
|---|---|
| ELT in Snowflake, transformations in dbt | SQL-first, version-controlled, tested, documented; analysts can contribute |
| RAW is all VARCHAR | A bad value never breaks a load; typing and its failures are visible in dbt |
| Quarantine instead of delete | Bad rows are triaged with the source owner, and counts are auditable |
| Star schema marts + KPI tables | Fast, simple Power BI models; one place per KPI |
| Semantic layer for metrics | Same definition for BI, notebooks and AI tools |
| DuckDB dev target | Anyone can run the full project and CI with no Snowflake account |
| Least-privilege roles (LOADER / TRANSFORMER / REPORTER) | BI users can never modify data; cost guarded by a resource monitor |
| AI explains governed outputs only | Numbers come from tested tables; every AI figure is checked before sharing |
