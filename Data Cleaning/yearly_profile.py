"""Describe how the clean dataset differs by year (run from the repository root).

Reads data/disruptions_2011_2025_clean.csv and Data Cleaning/output/yearly_retention.csv.
Writes Data Cleaning/output/yearly_profile.csv. Descriptive only: no data are changed.
"""
import csv
import statistics
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Data Cleaning/output/yearly_profile.csv"

retention = {r["year"]: r for r in csv.DictReader(open(ROOT / "Data Cleaning/output/yearly_retention.csv"))}
durations, causes = defaultdict(list), defaultdict(Counter)
with open(ROOT / "data/disruptions_2011_2025_clean.csv", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        durations[r["start_year"]].append(float(r["duration_minutes"]))
        causes[r["start_year"]][r["cause_group"]] += 1

rows = []
for year in sorted(durations):
    d, c, n = durations[year], causes[year], len(durations[year])
    top, top_n = c.most_common(1)[0]
    rows.append(dict(
        year=year, raw_rows=retention[year]["raw_rows"], clean_rows=n,
        retained_pct=retention[year]["retained_pct"],
        median_duration_min=statistics.median(d),
        pct_over_60_min=round(100 * sum(x > 60 for x in d) / n, 1),
        top_cause_group=top, top_cause_group_pct=round(100 * top_n / n, 1),
        pct_infrastructure=round(100 * c["infrastructure"] / n, 1),
        pct_rolling_stock=round(100 * c["rolling stock"] / n, 1),
        pct_unknown_cause=round(100 * c["unknown"] / n, 1),
    ))
with OUT.open("w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0]))
    w.writeheader()
    w.writerows(rows)
print(f"Wrote {OUT.relative_to(ROOT)} ({len(rows)} years)")
