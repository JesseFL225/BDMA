# Step 05 — Random forest

Owner: Oliver. Status: implemented, trained and evaluated on 2024 validation. Selected as the archived-context model.

> **Status 13 november 2026:** afgerond. Waar hieronder staat dat 2025 "locked"/"dicht" is of dat er geen testevaluatie is, beschrijft dat de situatie tijdens deze stap. De eindtest is daarna uitgevoerd in [stap 09](../09_modelkeuze_en_test/README.md). Het procesverhaal staat in [docs/PROCESVERLOOP.md](../../docs/PROCESVERLOOP.md).

## Goal and method

A ranger probability forest averages class probabilities from 200 bootstrap trees. Maximum depth is 12. Three candidates compare sqrt(p)/half-p feature sampling and minimum split-node sizes of 30/100. These are minimum node sizes before splitting, not guarantees of minimum terminal leaf size.
Predictions blend 99% forest probabilities with 1% Laplace-smoothed training class frequencies. This fixed design prevents zero probabilities for rare/absent classes without manufacturing training records. The blend is applied inside the model; the shared evaluator is not changed. No automatic class weighting or held-out resampling.

## Run

```sh
# If packages are missing (project-local installation):
Rscript moddeling/05_random_forest/install_dependencies.R
Rscript moddeling/05_random_forest/validate_tree_models.R
Rscript moddeling/05_random_forest/run_random_forest.R
```

Run from the BDMA root. Local packages and fitted-model caches under output/models/ are Git-ignored. Scripts regenerate these caches, predictions, tuning results and verification reports. Verified runtime package versions are recorded in output/verification_report.md; another version can change fitted values.

## Candidate grid

| candidate | mtry_rule | min_node_size |
|---|---|---|
| sqrt_leaf100 | sqrt | 100 |
| sqrt_leaf30 | sqrt |  30 |
| half_leaf100 | half | 100 |

## Selected settings

| feature_set | candidate | mean_log_loss | sd_log_loss |
|---|---|---|---|
| time_only | sqrt_leaf100 | 3.252920 | 0.1362771 |
| archived_context | sqrt_leaf100 | 3.081235 | 0.1279318 |

## Validation results

| Model | Features | Log_loss | Accuracy | Macro_F1 | Within_one_class |
|---|---|---|---|---|---|
| random_forest_prior_smoothed | time_only | 3.2139 | 11.74% | 0.0042 | 23.32% |
| random_forest_prior_smoothed | archived_context | 3.0591 | 12.31% | 0.0063 | 26.57% |

## Output and project impact

The output/ directory contains candidate/fold results, selected settings, compressed per-row probability tables, confusion matrices, class/ordinal metrics and verification. These artifacts make the model directly comparable to the saved baseline and logistic results. This step adds a nonlinear candidate; a small validation gain is not automatically a meaningful improvement.

## Shared design

Source: data/disruptions_2011_2025_clean.csv (44,248 selected disruptions). All 102 duration classes use the frozen Step 01 definition. Training 2011–2023; validation 2024; test 2025 remains locked. No additional cleaning or class merging.
Preparation and evaluation are imported unchanged from Mart's Steps 02 and 07. Time-only uses calendar features. Archived context additionally uses route/station features, top-20 training routes, hubs and explicitly enabled retrospective cause. Each forward fold refits preprocessing using its training rows only.
Hyperparameters are chosen on two forward folds: training through 2021 → 2022 and through 2022 → 2023. Mean log loss weights the two years equally. Ties use candidate-grid order. Settings are frozen before final fitting and 2024 scoring. Seed 42; two computational threads.

## Interpretation and limits

Archived fields can be revised after onset; context results are retrospective, not proof of live forecasting performance. Duration-based cleaning restricts the population to <=24 hours and disproportionately removes early records. Fixed-width classes are very imbalanced; even the final training contains classes with four records.
Accuracy is exact class accuracy. Within-one-class accuracy is not a ten-minute error guarantee. The final >=1010 class is open-ended and is reported separately. Feature importance is associational, not causal.

## Checks

Synthetic tests cover absent/nonadjacent class IDs, fixed 102-column probability order, positive normalised probabilities, serialized-model predictions, rejection of reordered features and evaluation of a class absent from training. Each final run verifies test locking, training IDs, saved prediction round-trips, model serialization and hashes of source data and Mart-owned Steps 01–04/07. See output/validation_checks.csv and output/verification_report.md.

## Handoff

Step 08 consumes the validation probability files with exactly the same 5,296 IDs and labels as Mart's saved results. Review the validation selection proposal together before Step 09. Do not unlock 2025 or change hyperparameters in response to its results.

## Change log

- Implemented and executed Oliver's model, chronological tuning, validation predictions and verification. No commits or pushes are part of these scripts. Code and report prepared with AI assistance.

## Primary implementation reference

https://imbs-hl.github.io/ranger/reference/ranger.html
