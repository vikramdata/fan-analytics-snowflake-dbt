.PHONY: data build docs insights load prod clean

data:      ## generate synthetic CSVs into data/raw
	python scripts/generate_data.py

build:     ## build + test everything locally on DuckDB
	dbt build --profiles-dir . --target dev

docs:      ## browse model docs and lineage
	dbt docs generate --profiles-dir . && dbt docs serve --profiles-dir .

insights:  ## write reports/ai_insights.md
	python scripts/ai_insights.py

load:      ## upload CSVs to Snowflake RAW
	python scripts/load_to_snowflake.py

prod:      ## build + test on Snowflake
	dbt build --profiles-dir . --target prod

clean:
	dbt clean --profiles-dir . && rm -f data/fan_analytics.duckdb
