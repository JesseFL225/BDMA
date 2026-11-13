# Step 09 — Frozen model choice and final 2025 test

Owners: Oliver and Mart. The user authorized the frozen model choice and 2025
assessment on 13 November 2026. The handoff and decision log are in
[HANDOVER.md](../../docs/HANDOVER.md).

## Inputs and decisions

Use Step 13's validation-selected models: recent-period time-only survival and
archived-context random forest. See `selection_plan.csv` for exact model paths,
training periods and comparator assignments. Selection uses log loss, not exact
accuracy. No refit on 2024 and no new tuning are part of this step.

The forest and survival models are separate information scenarios, not competing
live models with identical inputs. Archived context may contain revised causes
and affected routes. The clean population is outcome-selected.

## Execution and audit trail

`final_test.R` first verifies source/model/data hashes and reconstructs all 2024
predictions. Its default mode never imports 2025 outcomes. The authorized run with
`--unlock-test` saves predictions before opening test labels, then evaluates the
two selected models and two matched baselines using the unchanged shared evaluator.
`test_diagnostics.R` adds the prespecified uncertainty and subgroup diagnostics.

```sh
# Initial sequence, only before test outcomes have been opened:
Rscript moddeling/09_modelkeuze_en_test/final_test.R
Rscript moddeling/09_modelkeuze_en_test/final_test.R --unlock-test
# Safe independent verification of existing saved results:
python3 moddeling/09_modelkeuze_en_test/verify_saved_test.py
```

The run refuses to restart once `output/TEST_OUTCOMES_OPENED.txt` exists. This
prevents accidentally treating the test as unused. Do not delete the marker to
continue tuning. An exact reproduction in a separate checkout is different from
model development, but must still disclose that the year has already been seen.
For reproduction, fitted caches can be regenerated with Steps 05 and 13;
model-byte hashes must then be reviewed because serialization can differ even
when predictions are identical. Do not overwrite this run's provenance.

## Outputs and results

- `output/FINAL_TEST_REPORT.md`: final metrics, validation/test comparison and limits.
- `output/test_summary.csv`: all four models and uncertainty metrics.
- `output/test_bootstrap.csv`: paired day-bootstrap loss differences versus baselines.
- `output/test_thresholds.csv`, `test_calibration.csv`: recovery probability diagnostics.
- `output/test_groups.csv`: cause/month errors with group support.
- Compressed prediction files: all 102 probabilities for every included test ID.
- `frozen_manifest.csv`, `frozen_settings.md`, `frozen_test_ids.csv`: frozen provenance.
- `prediction_hashes_before_labels.csv`: saved forecasts before label import.
- `pretest_checks.csv`, `test_verification.md`, `independent_checks.csv`: verification.

The presence of `TEST_OUTCOMES_OPENED.txt` means 2025 is no longer an unused test
set. The final report is written only after scoring completes; the marker by
itself does not establish successful completion.

## Impact and handoff

Use the final test results to assess the previously selected models, not to
choose a new winner. Report negative findings and uncertainty. Later experiments
need a new holdout for a fresh final claim. Include at least three model families
from validation in the assignment; evaluating only two prespecified selected
models on the test does not erase the broader development comparison.

Keep report text within five pages, detailed diagnostics in the appendix, and
slides within ten. The final submission must include all analysis code and an
accessible exact dataset. No data changes, commits, pushes or deployment in this
step. Work was prepared with AI assistance and must be explainable by the team.
