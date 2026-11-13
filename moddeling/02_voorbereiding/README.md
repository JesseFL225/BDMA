# Step 02 — Shared data preparation

Owner: Mart. Reviewer: Oliver.

## Purpose and completed status

Implemented and executed shared, deterministic preparation for the 102-class
railway-disruption task. Both feature sets, training-fitted preprocessing,
chronological splits, leakage controls and validation checks are complete.
This step fits preprocessing only. Test outcomes remain locked by default.
Steps 03, 04 and 07 are now implemented separately; their READMEs report the
executed baseline, ridge-model and shared-evaluation results.

## Inputs and dependencies

Run scripts from the BDMA repository root. Dependencies: base R and the bundled
`tools` package only; no installation is needed.

- `data/disruptions_2011_2025_clean.csv`: verified 44,248 observations, 24 columns.
  MD5: `6f22afc6b05fe5e65ed8bd583bc5ba68`.
- `moddeling/01_target/output/classes.csv`: frozen 102 rows, IDs 0–101;
  `[0,10)`, …, `[1000,1010)`, `[1010,+Inf)`.
- `moddeling/01_target/define_duration_classes.R`: its existing
  `assign_duration_class` assignment is extracted with R's parser and evaluated
  in an isolated environment. The cutoff is passed from the frozen class table.
  The Step 01 driver is NOT sourced, its cutoff is NOT reselected, and its
  outputs are NOT regenerated. No independent assignment formula is introduced.
- Agreed conventions and their rationale: `docs/PROCESVERLOOP.md` (phase 2).

The clean CSV and every Step 01 file were hash-checked before and after tests
and were unchanged. Hashes and R/session versions are in `output/verification_report.md`.
MD5 identifies the input version; it is not a security guarantee.

## Functions and usage

```r
source("moddeling/02_voorbereiding/prepare_data.R")
prepared <- prepare_data()
X_train <- prepared$train$X$time_only
y_train <- prepared$train$y
X_validation <- prepared$validation$X$time_only

# Separate retrospective experiment, with explicit cause opt-in:
retrospective <- prepare_data(include_retrospective_cause = TRUE)

# Each tuning fold refits preprocessing on its own retained training rows:
fold <- prepare_data(train_years = 2011:2021, validation_years = 2022L)
```

`prepare_data()` orchestrates selective reading, split assignment, purging,
Step 01 assignment, feature engineering and preprocessing. Helper functions:
`load_duration_assigner()`, `parse_utc()`, `list_tokens()`,
`read_selected_outcomes()`, `engineer_features()`, `fit_preprocessor()` and
`apply_preprocessor()`. Sourcing or calling `prepare_data()` writes no files.
`validate_preparation.R` executes checks and writes only Step 02 reports.

## Splits and exclusions

Use start timestamps, converted from UTC to `Europe/Amsterdam` local years.
Recomputed years must agree with both stored year fields. All IDs must be present
and unique; any mismatch fails explicitly rather than silently dropping records.

| Split | Local start years | Rows retained |
|---|---|---:|
| Training | 2011–2023 | 33,004 |
| Validation | 2024 | 5,296 |
| Test | 2025 | 5,948 |

For each call, purge training events whose end is at or after local midnight
on January 1 of the first validation year. The rule is strict: labels must be
available BEFORE the next period. The main split and the two executed forward
folds have zero boundary exclusions. A synthetic crossing event was correctly
excluded. End time is used only for label availability and never as a feature.

Forward folds retain only the requested train/validation/test years. Other years
are explicitly listed in `exclusions` as `outside_requested_years`; they are not
silently lost. Executed examples:

| Train through | Validation | Training rows | Validation rows | Outside requested years |
|---|---|---:|---:|---:|
| 2021 | 2022 | 23,470 | 4,975 | 9,855 |
| 2022 | 2023 | 28,445 | 4,559 | 5,296 |

Test rows are prepared as feature matrices, but their outcome columns are not
imported by default. `y`, `class_id` and `duration_minutes` remain NA, with
`outcome_available = FALSE`. `include_test_outcomes = TRUE` exists for the later,
explicitly authorised final evaluation after model selection; it was NOT used
in this implementation or validation run. Never pass 2025 as a development year.

## Features and preprocessing

### time_only: 45 columns

- Local hour: 24 fixed one-hot columns.
- Local weekday: 7 one-hot columns, Monday = 1.
- Local month: 12 one-hot columns.
- Weekend indicator.
- Rush-hour indicator: Monday–Friday, 07:00–08:59 and 16:00–18:59 local time.

Calendar levels are domain constants, not estimated from held-out observations.
The hour conversion was tested with a summer daylight-saving example.

### archived_context: 74 columns by default

Includes time-only features plus:

- Counts of unique comma-separated route IDs and station codes.
- Route and station missingness flags. Missing lists produce unknown counts,
  not observed zero counts. Training-median imputation is applied afterward.
- Five fixed station-presence flags: Amsterdam Centraal (ASD), Utrecht Centraal
  (UT), Rotterdam Centraal (RTD), Schiphol Airport (SHL), Den Haag Centraal (GVC).
  Unknown station lists have zero flags PLUS an explicit missingness indicator.
- Multi-hot flags for the top 20 individual route IDs by number of retained
  training events containing each route. Duplicates within an event count once.
  Ties are broken lexically. Unknown routes activate no known-route flag, while
  their count and missingness are still represented. Vocabulary is stored in
  `preprocessing$archived_context$top_routes`.
- Optional retrospective cause group: enabled ONLY with
  `include_retrospective_cause = TRUE`. Adds training-vocabulary one-hot columns,
  explicit missing and unseen categories, and a cause-missing indicator.
  The clean data's `unknown` cause label remains a category and is also flagged.

**Retrospective limitation:** archived routes, stations and causes may have been
revised after onset. This feature set is not established as suitable for live
prediction, with or without cause. Compare algorithms using identical settings.

Numeric fields (counts and binary indicators) use training-median imputation,
training-mean centring and training-SD scaling by default. Constant/all-missing
training fields use scale 1; an all-missing field has fallback median 0 and its
missingness indicator. Set `scale_numeric = FALSE` consistently across models if
unscaled counts/flags are needed. One-hot and route flags remain 0/1.

Only retained training rows determine medians, means, SDs, route vocabulary and
cause vocabulary. The same fitted transformation is applied to other splits.
No ID, year trend, end time, duration, binary duration target, statistical cause
or calculated/difference-duration field enters a model matrix.

## Return contract for Oliver and shared evaluation

```text
prepared
  train / validation / test
    ids                 character vector, row-aligned with X and y
    X
      time_only         finite numeric matrix
      archived_context  finite numeric matrix
    y                   ordered factor, fixed 102 levels (test NA by default)
    class_id            integer 0–101 (test NA by default)
    duration_minutes    true recorded duration (test NA by default)
    metadata            IDs, split, UTC start, local year, outcome availability
  classes               frozen Step 01 class table
  class_levels          labels in fixed order
  probability_columns   p_0000_0010, …, p_1010_plus
  preprocessing         fitted parameters, feature order inputs, fit IDs/rows
  exclusions            ID and explicit reason for every excluded record
  audit                 input hashes, split counts, periods, boundary checks,
                        class counts, outcome lock state and R version
```

Matrix columns and ordering match across all three splits for each feature set.
`preprocessing$*$fit_rows` refers to original CSV row positions; `fit_ids` is the
portable identifier. Select ONE feature set per experiment and use its identical
columns for every algorithm. Do not append evaluation metadata to X.
If a modelling package requires an unordered response factor, preserve
`prepared$class_levels` explicitly when converting it. Numeric class IDs for
boosting are zero-based; probability output must follow `probability_columns`.
Never drop unused factor levels silently.

For new records, use `engineer_features()` with the same cause setting followed
by `apply_preprocessor(features, seq_len(nrow(new_data)), saved_preprocessor)`.
For tuning folds, call `prepare_data()` again with the appropriate years instead
of reusing full-training fitted parameters. Calls do not mutate the input CSV.

## Executed verification and outputs

Run:

```r
source("moddeling/02_voorbereiding/validate_preparation.R")
```

Or from a terminal at the repository root:

```sh
Rscript moddeling/02_voorbereiding/validate_preparation.R
```

34 checks passed in the executed run. Checks include actual split counts, unique
and disjoint IDs, ordered target levels, all seven requested class boundaries,
aligned finite matrices, predictor exclusions, retained-training fit IDs,
unknown cause handling, deduplicated route/station counts, training-only
imputation, held-out perturbation invariance, a synthetic boundary crossing,
locked malformed test outcomes, daylight-saving conversion, two real forward
folds, and preservation of all protected inputs.

Small CSV/Markdown outputs under `output/`:
`validation_checks.csv`, `split_counts.csv`, `class_boundary_checks.csv`,
`exclusions.csv`, `forward_fold_counts.csv`, `feature_sets.csv`,
`training_class_counts.csv`, and `verification_report.md`.
Matrices and fitted predictive models are not written to disk.

## Assumptions, limitations and remaining work

- The cleaner defines a selected domestic, valid-duration population capped at
  24 hours using eventual outcomes. Evaluation will not establish performance
  for every new disruption. Early years were strongly filtered.
- The frozen target was selected using all 2011–2023 training data. Forward
  tuning keeps that agreed label definition fixed; it does not reselect bins.
- Rare classes remain difficult. All 102 classes are retained even if a forward
  fold lacks examples; model-specific missing-class probability handling still
  needs agreement in Step 07. No such model behaviour has been tested here.
- Rush hours and five hub stations are explicit assumptions, not optimised
  using validation/test. Oliver should review them before model comparison.
- Selective outcome reading requires one CSV record per physical line. The
  reader checks this assumption and fails rather than misaligning records.
- Default expected input size is 44,248; updated versions fail until deliberately
  reviewed. Hashes are reported, not enforced against a hard-coded security hash.
- Full-corpus cleaning is existing work, not repeated here. No test outcome
  analysis, model selection, hyperparameter tuning or predictive training occurred.
- Existing unrelated working changes were preserved. No branch changes,
  commits, pushes or merges were performed.

## Next handover and change log

Completed: Step 02 code, validation and documentation. Oliver can source this
contract for forest/boosting. Steps 03 and 04 provide completed reference results
using the Step 07 evaluator. Retrospective experiments must be labelled.

2026-11-11: Implemented preparation and executed 34 checks; review by Oliver is
pending. No model performance results are claimed.
