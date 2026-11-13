# Step 08 — Validation error analysis

Owner: Oliver; review: Mart. Status: all eight saved prediction sets compared.

> **Status 13 November 2026:** completed. Where this README says 2025 is "locked" or that there is no test evaluation, it describes the situation during this step. The final test was run afterwards in [step 09](../09_modelkeuze_en_test/README.md). The full story is in [docs/PROCESS.md](../../docs/PROCESS.md).

## Goal and actions

Re-evaluate Mart's baselines/logistic regression and Oliver's forest/boosting with the unchanged shared evaluator and exactly the same validation IDs and labels. Identify errors by class, cause, month, season, rush hour and the training-selected top routes. Propose a model by validation log loss, separately for time-only and archived context.

## Run

```sh
Rscript moddeling/08_foutanalyse/run_error_analysis.R
```

Requires saved Steps 03–06 predictions and local Step 05/06 fitted-model caches for permutation importance. Re-run model scripts to recreate missing caches. Source data are read only; the metadata import does not load duration/end-time columns. Steps 01–04 and 07 are not modified.

## Validation comparison

| Model | Features | Log_loss | Accuracy | Macro_F1 | Within_one_class |
|---|---|---|---|---|---|
| random_forest_prior_smoothed | archived_context | 3.0591 | 12.31% | 0.0063 | 26.57% |
| cause_group_shrinkage_retrospective | archived_context | 3.0716 | 11.78% | 0.0047 | 27.13% |
| multinomial_ridge | archived_context | 3.0820 | 12.76% | 0.0096 | 27.96% |
| xgboost_multiclass | archived_context | 3.0844 | 11.63% | 0.0104 | 28.44% |
| random_forest_prior_smoothed | time_only | 3.2139 | 11.74% | 0.0042 | 23.32% |
| multinomial_ridge | time_only | 3.2173 | 11.78% | 0.0027 | 23.51% |
| xgboost_multiclass | time_only | 3.2195 | 11.86% | 0.0036 | 23.17% |
| global_frequency_laplace | time_only | 3.2309 | 11.73% | 0.0021 | 22.85% |

## Selection proposal

| Model | Features | Log_loss | Accuracy | Macro_F1 | Within_one_class |
|---|---|---|---|---|---|
| random_forest_prior_smoothed | time_only | 3.2139 | 11.74% | 0.0042 | 23.32% |
| random_forest_prior_smoothed | archived_context | 3.0591 | 12.31% | 0.0063 | 26.57% |

These are validation choices, not a final test result or operational deployment decision. The grid is deliberately small. Additional tuning would be a new development experiment, not a reason to reuse test outcomes.

## Error interpretation

The selected archived-context model underestimates the class in 81.33% of validation records, predicts the exact class in 12.31% and overestimates in 6.36%.
Argmax optimises the chosen class under equal misclassification costs; it tends to favour common short-duration classes. A lower probability log loss does not imply useful precise time estimates. The 102-class design is retained; no inconvenient classes are dropped.

Cause groups with the highest log loss for that model, among groups with at least 50 records:

| group | n | accuracy | under_rate | log_loss |
|---|---|---|---|---|
| staff |   89 | 0.02247191 | 0.0000000 | 4.658934 |
| engineering work |  126 | 0.07142857 | 0.7380952 | 4.251498 |
| infrastructure | 1303 | 0.06139678 | 0.8795088 | 3.759878 |
| logistical |  121 | 0.02479339 | 0.9090909 | 3.550779 |

All subgroup counts/rates are in output/subgroup_errors.csv. Route groups overlap; their counts must not be added to produce a total. Class-specific recall is NA when validation support is zero. Small groups are flagged, and no claim of significance is inferred from the ranking.

## Uncertainty and explanation

Paired differences in mean log loss are bootstrapped over observed calendar days (500 replicates). Negative differences favour the selected model. The intervals describe validation uncertainty after selection; they are not an unbiased post-selection test, do not adjust for all comparisons and do not capture all serial/network dependence.

| feature_set | selected | comparator | log_loss_difference | lower_95 | upper_95 | days | replicates |
|---|---|---|---|---|---|---|---|
| time_only | forest_time | logistic_time | -0.003368555 | -0.01358834 |  0.006085116 | 366 | 500 |
| time_only | forest_time | boosting_time | -0.005584230 | -0.01606401 |  0.003198815 | 366 | 500 |
| time_only | forest_time | global | -0.016964990 | -0.03119450 | -0.004073275 | 366 | 500 |
| archived_context | forest_context | cause | -0.012490631 | -0.02094066 | -0.003682081 | 366 | 500 |
| archived_context | forest_context | logistic_context | -0.022963777 | -0.03252548 | -0.014206921 | 366 | 500 |
| archived_context | forest_context | boosting_context | -0.025338537 | -0.03827485 | -0.014283342 | 366 | 500 |

Grouped permutation importance uses a fixed random sample of 2,000 validation rows and three shuffles. Time-of-week, month, route/station context and archived cause are permuted as coherent column blocks. Values are increases in log loss. Error bars show standard deviation across three permutations, not confidence intervals. Correlation can mask importance; these are predictive associations, not causal mechanisms.

| model | feature_set | group | mean_log_loss_increase | sd_log_loss_increase |
|---|---|---|---|---|
| random_forest_prior_smoothed | archived_context | cause |  0.2648549636 | 0.007036593 |
| random_forest_prior_smoothed | archived_context | month |  0.0003298288 | 0.001190968 |
| random_forest_prior_smoothed | time_only | month | -0.0018006092 | 0.001027574 |
| random_forest_prior_smoothed | archived_context | route_station_context |  0.0224213884 | 0.003412146 |
| random_forest_prior_smoothed | archived_context | time_of_week |  0.0213423134 | 0.001707939 |
| random_forest_prior_smoothed | time_only | time_of_week |  0.0410817678 | 0.005010157 |

## Figures and handoff

- output/validation_model_comparison.png: probability log loss by feature set.
- output/validation_error_direction.png: under/exact/over class predictions.
- output/grouped_permutation_importance.png: grouped associations for the best Oliver tree per feature set.
- output/selected_context_confusion_matrix.png: row-normalised confusion matrix of the selected context model.
- output/errors_per_class.csv and ordinal_comparison.csv: full support and open-ended-class diagnostics.

## Project impact and limitations

The experiments provide comparable nonlinear candidates and expose the limits of ten-minute resolution. They do not establish reliable minute-level travel advice. Retrospective cause/location availability, duration-based selection, early-year coverage and weak rare-class support remain material limitations. Step 09 is a joint decision: review this proposal and freeze the analysis before unlocking 2025. No new target, data cleaning, cost ratio or test selection has been introduced.

## Verification and change log

All eight files passed ID/label/probability checks in the shared evaluator. Source/Mart-file hashes were preserved and test outcomes remained unavailable. See output/verification_report.md. Implemented scripts and generated validation outputs; AI assistance used.
