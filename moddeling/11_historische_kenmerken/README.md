# Step 11 — Experiment 2: historical features

Owner: Oliver. Status: implemented and evaluated on 2024. Development experiment before the Step 09 final test. No gain; not adopted.

> **Status 13 November 2026:** completed. Where this README says 2025 is "locked" or that there is no test evaluation, it describes the situation during this step. The final test was run afterwards in [step 09](../09_modelkeuze_en_test/README.md). The full story is in [docs/PROCESS.md](../../docs/PROCESS.md).

## Goal and method

Measure whether historical information improves Step 10 absolute-error regression. Same clean dataset, feature preprocessing, cohorts and previously selected model settings. No external data, new cleaning, new tuning or test evaluation.

## Added features

Both feature sets add network-wide prior-start counts (24 hours and 7 days), number and median duration of globally completed events (90 days), and a missing-history indicator. Counts refer to events retained in this selected archive, not all real-world disruptions.
Archived context additionally adds counts of earlier events sharing any route (7/30 days), number and median duration of completed events sharing a route (90 days), and number/median duration of completed events in the same archived cause group (90 days). Events sharing multiple routes count once. Median features have missingness indicators and training-fitted imputation; count zero is a real zero.

## Chronology and assumptions

Previous starts must be strictly earlier than the current start. Duration features use only events whose recorded end precedes the current start; the 90-day window uses completion time. Equal-time and current events are excluded. Global/route/cause historical outcomes are not accessible while those events are running.
Earlier validation events may update history after completion; models remain fixed. This simulates sequential prediction during 2024, not a batch forecast made on 1 January. The same rule applies in the earlier folds. No 2025 outcomes are loaded.
Important limitation: we use the final, outcome-filtered clean archive. Its membership is not knowable at onset, and route/cause fields may have been revised. Start counts are therefore retrospective counts of eligible events, not validated real-time load measures. Even strict temporal indexing does not remove this selection/availability issue. The actual delay between an end event and its publication is unknown. These are historical proof-of-concept results within the selected population.

## Results

| Features | Variant | MAE_minutes | Within_10_pct | Within_20_pct | Exact_class_pct |
|---|---|---:|---:|---:|---:|
| time_only | original | 75.03 | 13.24 | 27.76 | 6.67 |
| time_only | history | 75.13 | 13.37 | 28.27 | 6.89 |
| archived_context | original | 68.06 | 18.66 | 36.67 | 9.25 |
| archived_context | history | 68.95 | 19.18 | 37.25 | 9.89 |

Lower MAE is better; tolerances include their boundaries. Exact-class accuracy uses the unchanged 102-class definition. Descriptive paired calendar-day bootstrap intervals are in output/paired_day_bootstrap.csv; negative differences favour history. Forward-fold results provide an earlier-year check, not an independent test: their settings were previously selected using those years.

## Project impact

Observed result: history does not improve MAE in either feature set on 2024. Context MAE rises from 68.06 to 68.95 minutes, while within-20-minute coverage rises from 36.67% to 37.25%. Both descriptive bootstrap intervals for MAE differences include zero. Retain Step 10 as the MAE reference; the small tolerance gains do not establish an overall improvement.

This experiment isolates one feature block while keeping model settings fixed. Retain or reject history based on the measured trade-offs, not a promise that more columns always help. Repeated work on 2024 can overfit validation; 2025 must remain reserved. This step does not automatically replace the original model or start an external-data experiment.

## Run and outputs

```sh
Rscript moddeling/11_historische_kenmerken/run_history_regression.R
```

Uses the existing local xgboost installation and Step 10 saved predictions/settings. history_features.R builds history; validate_history.R checks simultaneous events, uncompleted outcomes, multi-route deduplication, empty history, future-label perturbations and row-order invariance. Outputs contain development features, per-row chronology checks, imputation, fold comparisons, predictions, metrics and verification. Model caches are Git-ignored.

## Handoff and change log

Review results against Step 10 before deciding on retuning, new data or final model selection. Original data and Steps 01–10 remain unchanged. Implemented with AI assistance; no commits, pushes or test unlocking performed by these scripts.
