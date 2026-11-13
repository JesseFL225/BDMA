"""Independently verify saved final predictions; never fit or select models."""
from pathlib import Path
import csv
import gzip
import math

base = Path('moddeling/09_modelkeuze_en_test/output')
with (base / 'test_summary.csv').open() as handle:
    scores = list(csv.DictReader(handle))
with (base / 'frozen_test_ids.csv').open() as handle:
    expected_ids = [r['rdt_id'] for r in csv.DictReader(handle)]
checks = []
for score in scores:
    key = score['key']
    with gzip.open(base / (key + '_test_predictions.csv.gz'), 'rt') as handle:
        rows = list(csv.DictReader(handle))
    with gzip.open(base / (key + '_before_labels.csv.gz'), 'rt') as handle:
        before = list(csv.DictReader(handle))
    assert [r['rdt_id'] for r in rows] == expected_ids
    assert [r['rdt_id'] for r in before] == expected_ids
    assert len(set(expected_ids)) == len(expected_ids) == int(score['n'])
    loss = accuracy = rps = coverage = finite_count = finite_width = 0
    for row, original in zip(rows, before):
        columns = [k for k in row if k.startswith('p_')]
        assert len(columns) == 102 and row['split'] == 'test'
        p = [float(row[k]) for k in columns]
        assert p == [float(original[k]) for k in columns]
        assert all(math.isfinite(v) and 0 <= v <= 1 for v in p)
        assert abs(sum(p)-1) < 1e-10
        labels = [k[2:] for k in columns]
        truth = labels.index(row['true_class'])
        predicted = p.index(max(p))
        assert labels[predicted] == row['predicted_class']
        loss -= math.log(p[truth]); accuracy += predicted == truth
        cumulative = 0
        cdf = []
        for j, v in enumerate(p):
            cumulative += v; cdf.append(cumulative)
            if j < 101:
                rps += (cumulative - int(truth <= j))**2 / 101
        cdf[-1] = 1
        lo = next(j for j, v in enumerate(cdf) if v >= .1)
        hi = next(j for j, v in enumerate(cdf) if v >= .9)
        coverage += lo <= truth <= hi
        if hi < 101:
            finite_count += 1
            finite_width += (hi + 1 - lo) * 10
    n = len(rows)
    for metric, value in [('log_loss', loss/n), ('accuracy', accuracy/n),
                          ('rps', rps/n), ('central80_coverage', coverage/n),
                          ('finite_interval_fraction', finite_count/n),
                          ('mean_finite_width_minutes', finite_width/finite_count)]:
        assert math.isclose(value, float(score[metric]), rel_tol=1e-9), (key, metric)
    checks.append({'model': key, 'check': 'IDs, pre-label probabilities, log loss, accuracy, RPS and intervals', 'passed': True})
with (base / 'independent_checks.csv').open('w') as handle:
    writer = csv.DictWriter(handle, fieldnames=['model', 'check', 'passed'])
    writer.writeheader(); writer.writerows(checks)
print('All four frozen test prediction tables independently verified.')
