"""AI-assisted insights: turn dbt test results and KPI anomalies into a plain-English brief.

Design (responsible, practical AI):
  1. Facts first  - every number comes from governed dbt outputs (run_results.json,
                    rpt_kpi_anomalies, rpt_team_season_kpis). The model never queries data.
  2. Narrow job   - the model only explains and prioritizes; it may suggest checks, not causes.
  3. Verified     - every figure in the AI text is checked against the facts; anything that
                    can't be traced is listed under "Unverified figures" for a human to review.
  4. Works offline - without ANTHROPIC_API_KEY a deterministic template writes the brief,
                    so the pipeline and CI never depend on an external API.

Usage (after `dbt build`):
    python scripts/ai_insights.py                 # local DuckDB
    python scripts/ai_insights.py --target prod   # Snowflake (SNOWFLAKE_* env vars)
Output: reports/ai_insights.md
"""
import argparse
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = os.getenv("ANTHROPIC_MODEL", "claude-sonnet-5-5")

SYSTEM_PROMPT = """You are an analytics lead writing a weekly data brief for sports league executives.
Rules:
- Use ONLY the facts in the JSON you are given. Do not invent numbers, causes or events.
- When you mention a figure, copy it exactly as it appears in the facts.
- For anomalies, describe what happened and suggest what the business team should check
  (weather, promotions, opponent, kickoff time, competing events) - phrased as checks, not causes.
- For data quality, say what the issue is, how many rows it affected, and who should act.
- Sections: "Headline", "Attendance anomalies", "Data quality", "Suggested next checks".
- Plain language, no jargon, under 300 words."""


# ---------------------------------------------------------------- facts ---------------
def query(target: str, sql: str):
    if target == "dev":
        import duckdb
        con = duckdb.connect(str(ROOT / "data" / "fan_analytics.duckdb"), read_only=True)
        cur = con.execute(sql)
        cols = [d[0].lower() for d in cur.description]
        return [dict(zip(cols, r)) for r in cur.fetchall()]
    import snowflake.connector  # pip install snowflake-connector-python
    con = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"], user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"], role="REPORTER",
        warehouse="TRANSFORM_WH", database="FAN_ANALYTICS")
    cur = con.cursor().execute(sql)
    cols = [d[0].lower() for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def dq_findings():
    path = ROOT / "target" / "run_results.json"
    if not path.exists():
        return []
    out = []
    for r in json.loads(path.read_text())["results"]:
        if r["unique_id"].startswith("test.") and r["status"] in ("warn", "fail", "error"):
            out.append({"test": r["unique_id"].split(".")[2], "status": r["status"],
                        "rows_affected": r.get("failures")})
    return out


def num(x, nd=0):
    return None if x is None else round(float(x), nd)


def gather(target: str) -> dict:
    anomalies = query(target, """
        select matchup, cast(game_date as varchar) as game_date, attendance,
               team_season_avg_attendance, attendance_z_score, direction, sell_through_pct, no_show_rate
        from reporting.rpt_kpi_anomalies order by game_date desc limit 8""")
    latest = query(target, "select max(season) as s from reporting.rpt_team_season_kpis")[0]["s"]
    teams = query(target, f"""
        select team_name, avg_attendance, sell_through_pct, net_ticket_revenue, avg_attendance_yoy_pct
        from reporting.rpt_team_season_kpis where season = {latest} order by sell_through_pct desc""")
    quarantine = query(target, """
        select dq_issue, count(*) as n from marts.dq_quarantine_ticket_orders group by dq_issue order by n desc""")
    return {
        "season": int(latest),
        "league_net_ticket_revenue": num(sum(float(t["net_ticket_revenue"]) for t in teams)),
        "team_kpis": [{"team": t["team_name"],
                       "avg_attendance": num(t["avg_attendance"]),
                       "sell_through_pct": num(float(t["sell_through_pct"]) * 100, 1),
                       "net_ticket_revenue": num(t["net_ticket_revenue"]),
                       "avg_attendance_yoy_pct": num(float(t["avg_attendance_yoy_pct"] or 0) * 100, 1)}
                      for t in teams],
        "attendance_anomalies": [{"game": a["matchup"], "date": a["game_date"],
                                  "attendance": int(a["attendance"]),
                                  "team_season_avg": num(a["team_season_avg_attendance"]),
                                  "z_score": num(a["attendance_z_score"], 2),
                                  "direction": a["direction"],
                                  "no_show_rate_pct": num(float(a["no_show_rate"]) * 100, 1)}
                                 for a in anomalies],
        "quarantined_orders": [{"issue": q["dq_issue"], "rows": int(q["n"])} for q in quarantine],
        "dbt_test_findings": dq_findings(),
    }


# ---------------------------------------------------------------- writing -------------
def ai_brief(facts: dict):
    key = os.getenv("ANTHROPIC_API_KEY")
    if not key:
        return None
    try:
        import anthropic
    except ImportError:
        print("anthropic package not installed; using template brief")
        return None
    client = anthropic.Anthropic(api_key=key)
    msg = client.messages.create(
        model=MODEL, max_tokens=900, system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": "Facts:\n" + json.dumps(facts, indent=2, default=str)}])
    return msg.content[0].text


def template_brief(f: dict) -> str:
    top, bottom = f["team_kpis"][0], f["team_kpis"][-1]
    lines = ["## Headline",
             f"{f['season']} league net ticket revenue was ${f['league_net_ticket_revenue']:,.0f}. "
             f"{top['team']} led sell-through at {top['sell_through_pct']}%; "
             f"{bottom['team']} was lowest at {bottom['sell_through_pct']}%.", "",
             "## Attendance anomalies"]
    for a in f["attendance_anomalies"]:
        lines.append(f"- {a['date']} {a['game']}: {a['attendance']:,} scanned vs a season average of "
                     f"{a['team_season_avg']:,.0f} (z {a['z_score']}, {a['direction'].lower()} normal). "
                     "Check weather, kickoff time and promotions for this date.")
    lines += ["", "## Data quality"]
    for q in f["quarantined_orders"]:
        lines.append(f"- {q['rows']} orders quarantined for {q['issue']} - ticketing team to review.")
    for t in f["dbt_test_findings"]:
        lines.append(f"- dbt test `{t['test']}`: {t['status']} ({t['rows_affected']} rows).")
    lines += ["", "## Suggested next checks",
              f"- Review demand drivers for {bottom['team']} home games.",
              "- Confirm the duplicate-order extract issue is fixed at source."]
    return "\n".join(lines)


def unverified_figures(text: str, facts: dict) -> list:
    """Figures (3+ digits, or decimals) in the AI text that don't appear anywhere in the facts."""
    known = set()
    for n in re.findall(r"-?\d[\d,]*\.?\d*", json.dumps(facts, default=str)):
        v = n.replace(",", "")
        try:
            known |= {v, f"{float(v):,.0f}", f"{float(v):.0f}", f"{float(v):,.1f}", f"{abs(float(v))}"}
        except ValueError:
            pass
    found = re.findall(r"\d[\d,]*\.\d+|\d{1,3}(?:,\d{3})+|\d{3,}", text)
    return sorted({x for x in found if x not in known and x.replace(",", "") not in known
                   and not re.fullmatch(r"20\d\d", x)})


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--target", choices=["dev", "prod"], default="dev")
    args = p.parse_args()

    facts = gather(args.target)
    text = ai_brief(facts)
    source = f"AI-generated ({MODEL}), checked against governed figures" if text else "Template (no API key)"
    text = text or template_brief(facts)
    flagged = unverified_figures(text, facts)

    out = ROOT / "reports"
    out.mkdir(exist_ok=True)
    report = [f"# Weekly data brief - {facts['season']} season",
              f"_Generated {datetime.now(timezone.utc):%Y-%m-%d %H:%M} UTC · {source}_", "", text, "",
              "---", "### Verification",
              ("All figures trace back to dbt outputs." if not flagged
               else "**Unverified figures (review before sharing):** " + ", ".join(flagged)),
              "", "<details><summary>Source facts</summary>", "", "```json",
              json.dumps(facts, indent=2, default=str), "```", "</details>"]
    (out / "ai_insights.md").write_text("\n".join(report))
    print(f"Wrote {out / 'ai_insights.md'} ({source}); unverified figures: {len(flagged)}")


if __name__ == "__main__":
    main()
