"""Independent standard-library verification of saved R model predictions."""
from pathlib import Path
import csv
import gzip
import math

base = Path("moddeling/13_survival/output")
with (base / "all_model_comparison.csv").open() as handle:
    expected = {row["key"]: row for row in csv.DictReader(handle)}
files = {
    "survival_time": "time_only",
    "survival_context": "archived_context",
    "survival_recent_time": "time_only_since2017",
    "survival_recent_context": "archived_context_since2017",
}
checks = []
for key, stem in files.items():
    with gzip.open(base / (stem + "_validation_predictions.csv.gz"), "rt") as handle:
        rows = list(csv.DictReader(handle))
    losses, scores, hits, ids = [], [], [], []
    for row in rows:
        cols = [column for column in row if column.startswith("p_")]
        assert len(cols) == 102
        labels = [column[2:] for column in cols]
        p = [float(row[column]) for column in cols]
        truth = labels.index(row["true_class"])
        assert all(math.isfinite(v) and 0 <= v <= 1 for v in p)
        assert abs(sum(p) - 1) < 1e-10
        predicted = p.index(max(p))
        assert row["predicted_class"] == labels[predicted]
        losses.append(-math.log(p[truth]))
        hits.append(predicted == truth)
        cumulative = error = 0
        for j, probability in enumerate(p[:-1]):
            cumulative += probability
            error += (cumulative - int(truth <= j)) ** 2
        scores.append(error / 101)
        ids.append(row["rdt_id"])
    assert len(set(ids)) == len(ids) == 5296
    for metric, values in [("log_loss", losses), ("accuracy", hits), ("rps", scores)]:
        assert math.isclose(sum(values) / len(values), float(expected[key][metric]), rel_tol=1e-10)
    checks.append({"check": key + " independent probability/logloss/accuracy/RPS verification", "passed": True})
with (base / "independent_checks.csv").open("w") as handle:
    writer = csv.DictWriter(handle, fieldnames=["check", "passed"])
    writer.writeheader()
    writer.writerows(checks)
print("Four survival prediction files independently verified.")
