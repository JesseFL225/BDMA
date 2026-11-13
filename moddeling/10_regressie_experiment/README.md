# Step 10 — Experiment 1: regression with existing features

Owner: Oliver. Status: executed on training/validation only. This development experiment runs BEFORE the locked Step 09 final test, despite its folder number. Result not adopted (see docs/PROCESS.md, phase 5).

> **Status 13 November 2026:** completed. Where this README says 2025 is "locked" or that there is no test evaluation, it describes the situation during this step. The final test was run afterwards in [step 09](../09_modelkeuze_en_test/README.md). The full story is in [docs/PROCESS.md](../../docs/PROCESS.md).

## Question

Does learning duration directly help, without adding data or changing cohort eligibility?

## Method and input

The unchanged shared preparation provides 2011–2023 training, 2024 validation and locked 2025 outcomes. Both existing feature sets are used, with retrospective cause explicitly enabled for archived_context. No history features, external sources or new cleaning.
XGBoost reg:absoluteerror directly minimises L1 loss in minutes, targeting a conditional median. A constant training median is the baseline. Three candidates (depth 2/4, rounds 100/300, eta 0.05) are selected by equal-year average MAE on forward validation folds 2022 and 2023. No 2024 early stopping or further tuning. Predictions are clamped at zero, not rounded or capped at 1440.
Other fixed settings: min_child_weight=10, subsample=0.8, colsample_bytree=0.8, lambda=1, two threads, seed 42. Initial prediction is the fold training median.
Final training median: 51.0 minutes.

## Validation results

| Model | MAE_minutes | Within_10_pct | Within_20_pct | Exact_class_pct |
|---|---:|---:|---:|---:|
| Median baseline | 78.77 | 12.88 | 26.25 | 5.42 |
| Boosting: time | 75.03 | 13.24 | 27.76 | 6.67 |
| Boosting: context | 68.06 | 18.66 | 36.67 | 9.25 |

MAE is mean absolute minute error (lower better). Within ±10/±20 includes the boundary. Exact-class accuracy uses the original 102-class definition, including >=1010, and is not interchangeable with a minute-error tolerance. Log loss from classifiers and minute MAE are different units and cannot be compared numerically.

## Impact and limitations

Archived-context regression changes MAE by 13.61% relative to the global median baseline. This does not prove that new information is unnecessary or that the same gain holds on 2025.
Point regression does not produce class probabilities or prediction intervals. Those are separate future experiments. The objective changed from classification log loss to absolute error, so improved MAE need not mean improved exact-bin accuracy. Archived inputs may be revised after onset; only time-only results avoid that specific retrospective-context issue.
The previous 24-hour filter and historical exclusions still restrict generalisation. Paired calendar-day bootstrap intervals are descriptive validation uncertainty; repeated development against 2024 can overfit that year. Keep 2025 untouched.

## Files and checks

regression.R defines model/metrics; run_regression.R executes this experiment. output/ contains the grid, fold results, selected settings, validation predictions and metrics, day-bootstrap intervals, and verification. Model caches are local and Git-ignored. Checks cover manual error calculations/boundaries, serialization, CSV round-trip, test locking and protected-file hashes.

## Run

```sh
Rscript moddeling/10_regressie_experiment/run_regression.R
```

Requires the already installed xgboost package (optional setup: Rscript moddeling/05_random_forest/install_dependencies.R). Run from the BDMA root.

## Next step

Review these results before adding historical features. Keep this run as the fixed existing-feature comparator. Do not start the final test or replace the original classifiers automatically.

## Change log and source

Implemented and executed experiment 1 with AI assistance. Original data and previous modelling outputs preserved.
https://xgboost.readthedocs.io/en/stable/parameter.html
