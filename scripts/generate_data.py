"""Generate synthetic CFL-style ticketing and fan engagement data.

Team names and cities are real league facts; everything else (venues, capacities,
schedules, scores, orders, fans, engagement) is synthetic and generated here.

A small number of defects are planted on purpose (duplicate orders, negative prices,
orders for unknown games, events from unknown fans) so the dbt data quality tests
have something real to catch.

Usage:
    python scripts/generate_data.py            # writes CSVs to data/raw/
    python scripts/generate_data.py --scale 0.25   # smaller dataset for quick runs
"""
import argparse
from datetime import date, datetime, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 42
SEASONS = [2023, 2024, 2025]
OUT = Path(__file__).resolve().parents[1] / "data" / "raw"

TEAMS = [
    # team_id, team_name, city, province, division
    ("BC", "BC Lions", "Vancouver", "BC", "West"),
    ("CGY", "Calgary Stampeders", "Calgary", "AB", "West"),
    ("EDM", "Edmonton Elks", "Edmonton", "AB", "West"),
    ("SSK", "Saskatchewan Roughriders", "Regina", "SK", "West"),
    ("WPG", "Winnipeg Blue Bombers", "Winnipeg", "MB", "West"),
    ("HAM", "Hamilton Tiger-Cats", "Hamilton", "ON", "East"),
    ("TOR", "Toronto Argonauts", "Toronto", "ON", "East"),
    ("OTT", "Ottawa Redblacks", "Ottawa", "ON", "East"),
    ("MTL", "Montreal Alouettes", "Montreal", "QC", "East"),
]
# Synthetic capacities and "fan base strength" (drives demand) per team.
CAPACITY = {"BC": 27000, "CGY": 26000, "EDM": 32000, "SSK": 33000, "WPG": 32000,
            "HAM": 24000, "TOR": 26000, "OTT": 24000, "MTL": 23000}
DEMAND = {"BC": 0.68, "CGY": 0.80, "EDM": 0.62, "SSK": 0.93, "WPG": 0.90,
          "HAM": 0.86, "TOR": 0.58, "OTT": 0.78, "MTL": 0.74}
TIERS = [  # tier, share of capacity, base price
    ("PREMIUM", 0.08, 165.0), ("LOWER_BOWL", 0.42, 78.0),
    ("UPPER_BOWL", 0.35, 48.0), ("END_ZONE", 0.15, 36.0),
]
CHANNELS = ["primary_web", "mobile_app", "box_office", "season_ticket", "group_sales"]
CHANNEL_P = [0.38, 0.22, 0.07, 0.25, 0.08]
PROVINCES = ["BC", "AB", "SK", "MB", "ON", "QC", "NS", "NB", "NL", "PE"]
EVENT_TYPES = ["article_view", "video_view", "highlight_view", "game_tracker_view",
               "fantasy_entry", "push_open", "store_visit"]
EVENT_P = [0.24, 0.18, 0.2, 0.14, 0.06, 0.12, 0.06]


def build_venues(scale):
    # Capacity is scaled with the dataset so sell-through stays realistic at any --scale.
    rows = [(f"V_{t[0]}", f"{t[2]} Stadium", t[2], t[3], int(CAPACITY[t[0]] * scale)) for t in TEAMS]
    return pd.DataFrame(rows, columns=["venue_id", "venue_name", "city", "province", "capacity"])


def build_games(rng):
    ids = [t[0] for t in TEAMS]
    rows = []
    for season in SEASONS:
        n = 0
        pairs = [(h, a) for h in ids for a in ids if h != a]  # 72 games, 16 per team
        pairs += [(ids[i], ids[(i + 1) % 9]) for i in range(9)]  # +9 games -> 18 per team
        rng.shuffle(pairs)
        start = date(season, 6, 6)
        for i, (home, away) in enumerate(pairs):
            week = i // 4 + 1  # ~4 games per week over ~21 weeks
            gday = start + timedelta(days=(week - 1) * 7 + int(rng.choice([0, 1, 2, 3])))
            kickoff = rng.choice(["16:00", "19:00", "19:30", "20:00"])
            n += 1
            rows.append((f"G{season}{n:04d}", season, week, gday.isoformat(), kickoff,
                         "REGULAR", home, away, f"V_{home}",
                         int(rng.integers(10, 42)), int(rng.integers(8, 40))))
        # Grey Cup at a rotating host
        host = ids[SEASONS.index(season) * 3 % 9]
        h, a = rng.choice([i for i in ids if i != host], 2, replace=False)
        n += 1
        rows.append((f"G{season}{n:04d}", season, 23, date(season, 11, 16).isoformat(), "18:00",
                     "GREY_CUP", h, a, f"V_{host}", int(rng.integers(14, 38)), int(rng.integers(10, 35))))
    return pd.DataFrame(rows, columns=["game_id", "season", "week", "game_date", "kickoff_local",
                                       "game_type", "home_team_id", "away_team_id", "venue_id",
                                       "home_score", "away_score"])


def build_fans(rng, n_fans):
    signup = pd.to_datetime("2018-01-01") + pd.to_timedelta(rng.integers(0, 2700, n_fans), unit="D")
    fav = rng.choice([t[0] for t in TEAMS], n_fans, p=np.array(list(DEMAND.values())) / sum(DEMAND.values()))
    prov_of = {t[0]: t[3] for t in TEAMS}
    prov = np.where(rng.random(n_fans) < 0.85, [prov_of[f] for f in fav], rng.choice(PROVINCES, n_fans))
    return pd.DataFrame({
        "fan_id": [f"F{i:07d}" for i in range(1, n_fans + 1)],
        "signup_date": signup.date,
        "home_province": prov,
        "favourite_team_id": fav,
        "email_opt_in": rng.random(n_fans) < 0.57,
        "acquisition_channel": rng.choice(["ticket_purchase", "app_download", "contest", "newsletter", "store"],
                                          n_fans, p=[0.42, 0.25, 0.12, 0.13, 0.08]),
    })


def build_orders(rng, games, venues, fans):
    cap = venues.set_index("venue_id")["capacity"]
    # Only ~40% of CRM fans ever buy, and purchases are concentrated (season ticket holders,
    # loyal buyers), so each buyer gets a heavy-tailed purchase weight.
    buyers = fans.sample(frac=0.40, random_state=SEED).copy()
    buyers["w"] = rng.pareto(1.6, len(buyers)) + 1
    pools = {t: (g["fan_id"].to_numpy(), (g["w"] / g["w"].sum()).to_numpy())
             for t, g in buyers.groupby("favourite_team_id")}
    all_fans, all_w = buyers["fan_id"].to_numpy(), (buyers["w"] / buyers["w"].sum()).to_numpy()
    frames = []
    for g in games.itertuples():
        game_date = datetime.fromisoformat(g.game_date)
        base = 0.97 if g.game_type == "GREY_CUP" else DEMAND[g.home_team_id]
        season_trend = {2023: -0.03, 2024: 0.0, 2025: 0.03}[g.season]
        weekend = 0.04 if game_date.weekday() >= 4 else -0.03
        fill = float(np.clip(base + season_trend + weekend + rng.normal(0, 0.05), 0.35, 1.0))
        if rng.random() < 0.03:  # occasional weather / slump game, shows up as an anomaly
            fill *= 0.6
        for tier, share, price in TIERS:
            seats = int(cap[g.venue_id] * share * fill)
            if seats <= 0:
                continue
            qty = rng.choice([1, 2, 2, 2, 3, 4, 4, 6], size=max(1, seats // 3))
            qty = qty[np.cumsum(qty) <= seats]
            n = len(qty)
            if n == 0:
                continue
            days_before = np.clip(rng.exponential(18, n), 0, 160)
            order_ts = game_date - pd.to_timedelta(days_before, unit="D") + pd.to_timedelta(rng.integers(0, 86400, n), unit="s")
            channel = rng.choice(CHANNELS, n, p=CHANNEL_P)
            demand_mult = 0.9 + 0.35 * fill
            unit = np.round(price * demand_mult * rng.normal(1, 0.08, n), 2)
            unit = np.where(channel == "season_ticket", np.round(unit * 0.82, 2), unit)
            discount = np.where(channel == "group_sales", np.round(unit * qty * 0.12, 2), 0.0)
            home_fans, home_w = pools.get(g.home_team_id, (all_fans, all_w))
            fan = np.where(rng.random(n) < 0.8, rng.choice(home_fans, n, p=home_w), rng.choice(all_fans, n, p=all_w))
            status = np.where(rng.random(n) < 0.025, "REFUNDED", "COMPLETED")
            scanned = np.where(status == "COMPLETED",
                               np.minimum(qty, rng.binomial(qty, 0.9)), 0)
            frames.append(pd.DataFrame({
                "game_id": g.game_id, "fan_id": fan, "order_ts": order_ts.strftime("%Y-%m-%d %H:%M:%S"),
                "sales_channel": channel, "section_tier": tier, "quantity": qty,
                "unit_price": unit, "discount_amount": discount, "order_status": status,
                "tickets_scanned": scanned,
            }))
    orders = pd.concat(frames, ignore_index=True)
    orders.insert(0, "order_id", [f"O{i:08d}" for i in range(1, len(orders) + 1)])

    # ---- planted defects -------------------------------------------------
    dupes = orders.sample(25, random_state=SEED)                       # duplicate loads
    neg = orders.sample(12, random_state=SEED + 1).index               # negative prices
    orders.loc[neg, "unit_price"] = -orders.loc[neg, "unit_price"]
    orphan = orders.sample(8, random_state=SEED + 2).index             # unknown game
    orders.loc[orphan, "game_id"] = "G_UNKNOWN"
    return pd.concat([orders, dupes], ignore_index=True)


def build_events(rng, fans, games, n_events):
    # ~55% of fans use the app/web at all, with a heavy-tailed activity level.
    active = fans.sample(frac=0.55, random_state=SEED + 5)
    fan_ids = active["fan_id"].to_numpy()
    w = rng.pareto(1.4, len(fan_ids)) + 1
    w = w / w.sum()
    fav = fans.set_index("fan_id")["favourite_team_id"]
    # 60% of events cluster within 2 days of a game day
    gdates = pd.to_datetime(games["game_date"]).to_numpy()
    near = rng.random(n_events) < 0.6
    ts = np.where(
        near,
        pd.to_datetime(rng.choice(gdates, n_events)) + pd.to_timedelta(rng.integers(-2 * 86400, 2 * 86400, n_events), unit="s"),
        pd.to_datetime("2023-05-01") + pd.to_timedelta(rng.integers(0, 945 * 86400, n_events), unit="s"),
    )
    ts = pd.to_datetime(ts)
    fan = rng.choice(fan_ids, n_events, p=w)
    team = np.where(rng.random(n_events) < 0.75, fav.reindex(fan).to_numpy(), rng.choice([t[0] for t in TEAMS], n_events))
    ev = pd.DataFrame({
        "event_id": [f"E{i:09d}" for i in range(1, n_events + 1)],
        "fan_id": fan,
        "event_ts": ts.strftime("%Y-%m-%d %H:%M:%S"),
        "platform": rng.choice(["ios", "android", "web"], n_events, p=[0.38, 0.27, 0.35]),
        "event_type": rng.choice(EVENT_TYPES, n_events, p=EVENT_P),
        "team_id": team,
        "session_seconds": np.round(rng.gamma(2.0, 45, n_events)).astype(int),
    })
    bad = ev.sample(15, random_state=SEED + 3).index  # events from fans not in CRM
    ev.loc[bad, "fan_id"] = "F_UNKNOWN"
    return ev.sort_values("event_ts").reset_index(drop=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--scale", type=float, default=0.25,
                   help="fraction of real-world volume (1.0 ~ 1.8M orders); default 0.25")
    args = p.parse_args()
    rng = np.random.default_rng(SEED)
    OUT.mkdir(parents=True, exist_ok=True)

    teams = pd.DataFrame(TEAMS, columns=["team_id", "team_name", "city", "province", "division"])
    venues = build_venues(args.scale)
    games = build_games(rng)
    fans = build_fans(rng, int(160_000 * args.scale))
    orders = build_orders(rng, games, venues, fans)
    events = build_events(rng, fans, games, int(1_200_000 * args.scale))

    for name, df in [("teams", teams), ("venues", venues), ("games", games),
                     ("fans", fans), ("ticket_orders", orders), ("engagement_events", events)]:
        df.to_csv(OUT / f"{name}.csv", index=False)
        print(f"{name:<18} {len(df):>10,} rows")


if __name__ == "__main__":
    main()
