# Step 07 — Shared evaluation

Owner: Mart. Reviewer: Oliver.

## Purpose and status

Completed: algorithm-independent `evaluate_predictions()` and 56 executed
synthetic checks. Suitable for baseline, multinomial logistic regression,
random forest and gradient boosting outputs under the same contract.
The evaluator itself fits no models. Its tests use synthetic data only.
Steps 03 and 04 now apply it to real 2024 validation predictions; their READMEs
contain results and figures. Final cross-algorithm selection and 2025 testing
remain pending.

## Dependencies and frozen definitions

Base R plus bundled `tools` only. Run from the repository root.
`evaluate.R` reads `moddeling/01_target/output/classes.csv`: the 102 fixed
classes from `0000_0010` to `1010_plus`, IDs 0–101. It does not source the
Step 01 generation driver or recalculate any target definitions.
Step 02's prepared IDs, ordered factors and `probability_columns` are compatible.
The cleaned CSV, Step 01 and Step 02 were not modified; their hashes were checked
before and after the synthetic tests.

## Input contract and validation

One data.frame per model, feature set and split, with columns in EXACT order:

```text
rdt_id, split, model, feature_set, true_class, predicted_class,
p_0000_0010, p_0010_0020, …, p_1000_1010, p_1010_plus
```

- Nonempty data; no duplicate names, extra columns or missing fields.
- IDs must be nonmissing, nonblank and unique. Numeric finite IDs are accepted;
  character IDs preserve the Step 02 convention.
- Metadata is character/factor. `split` is `train`, `validation` or `test`;
  `feature_set` is `time_only` or `archived_context`. Exactly one value each
  for split, model and feature set; mixed experiments are rejected, not pooled.
- Class values are EXACT labels from classes.csv, not numeric IDs. Factors must
  include all 102 levels in the fixed order; character labels are also accepted.
- Probability columns are numeric, finite, nonmissing and in [0,1]. Each row
  sums to one within absolute tolerance 1e-8 by default. No clipping,
  normalisation, column rearrangement or observation removal occurs.
- `predicted_class` must be the first maximum-probability class in fixed order.
  This explicit tie policy is shared across algorithms.
- Supply `expected_ids` and `expected_true_class` from the prepared split for
  strict cohort and label verification. IDs and labels must match in exact row
  order. Missing, extra or reordered records are rejected, never joined/sorted.
  Without these optional references, the evaluator validates internal integrity
  but cannot establish cohort completeness or correctness of supplied truth.
- `test` inputs are rejected by default. `allow_test = TRUE` is reserved for an
  explicitly authorised final evaluation after settings/model choice are frozen;
  this option has not been used in the synthetic test run.

Supported signature:

```r
evaluate_predictions(
  predictions,
  classes_path = "moddeling/01_target/output/classes.csv",
  expected_ids = NULL,
  expected_true_class = NULL,
  probability_tolerance = 1e-8,
  allow_test = FALSE
)
```

## Metrics and conventions

Confusion-matrix rows are TRUE classes; columns are PREDICTED classes. All 102
rows and columns remain present even when no observations fall in a class.
For class k, TP is its diagonal cell, support is its true row total, and predicted
support is its column total.

| Metric | Definition and units |
|---|---|
| Multiclass log loss | Mean of `-log(p_true)`, natural logarithm; lower is better |
| Accuracy | Correct predictions / all records; proportion 0–1 |
| Per-class recall | TP / true support; NA if true support is zero |
| Per-class precision | TP / predicted support; NA if no predictions of this class |
| Per-class F1 | `2*TP / (true support + predicted support)`; zero when denominator is zero |
| Macro-F1 | Unweighted mean F1 over ALL 102 fixed classes |
| Within one class | Percentage with absolute ordinal offset ≤1; range 0–100 |
| Underestimation | Proportion with predicted class before true class |
| Overestimation | Proportion with predicted class after true class |

**Absent-class convention:** all 102 labels contribute to macro-F1. A class with
no validation observations has F1=0, whether predicted incorrectly or not
predicted at all. Recall is NA rather than an invented zero when its support is
zero. This fixed denominator applies to every model. Consequently, perfect
predictions on a subset containing just one class yield macro-F1=1/102, while
perfect predictions with all 102 classes observed yield 1. Support is always shown.

**Probability convention:** valid exact zero probabilities are retained.
Assigning zero to an observed true class produces infinite log loss. This
explicitly reveals model failures instead of silently adding smoothing.
If models use smoothing, define it consistently upstream using training only.
The evaluator never changes probabilities. Numerical sum tolerance is validation
only, not renormalisation.

**Ordered interpretation:** `class_offset = predicted_position - true_position`.
Negative means underestimation. The final `1010_plus` class is open-ended and
has no representative duration. Neither class offsets nor adjacent-class
accuracy are minute-error metrics; adjacent bins do not imply ≤10 minutes error.
No exact minute error or invented midpoint is calculated. `ordinal_summary`
separately reports all records, pairs where both intervals are finite, true
open-ended cases, and cases where either class is open-ended. These subsets
can overlap; empty subsets have n=0 and NA rates.

## Return structure

```text
summary             one-row metrics and split/model/feature-set identifiers
per_class           all 102 definitions, support, predicted support, TP,
                    precision, recall and F1
confusion_matrix    102 × 102 table, true rows / predicted columns
ordinal_summary     overall and open-ended/finite-interval subset rates
per_observation     original metadata in input order, true probability,
                    log loss, class offset, within-one flag, direction,
                    true/predicted open-ended flags
classes             frozen Step 01 table
settings            tolerance, conventions, reference verification flags,
                    class-file MD5 and R version
```

Sourcing/calling the evaluator has no file-writing side effects. For example,
export `result$summary` with `write.csv()` when a model run needs an artifact.

## Exact instructions for Oliver

Generate `P_validation` with one probability row per prepared validation ID and
columns in `prepared$class_levels` order. For ranger or boosting, deliberately
map the package's class names/zero-based IDs to that order in the model script;
do not assume its default order. Missing training classes still require 102
probability columns under an agreed upstream policy. The evaluator rejects any
missing column and does not invent missing-class probabilities.

```r
# prepared is the Step 02 object used by this model.
# P_validation is this model's numeric probability matrix, not yet evaluated.
source("moddeling/07_evaluatie/evaluate.R")
stopifnot(
  nrow(P_validation) == length(prepared$validation$ids),
  identical(colnames(P_validation), prepared$class_levels)
)
probabilities <- as.data.frame(P_validation)
names(probabilities) <- prepared$probability_columns
predictions <- data.frame(
  rdt_id = prepared$validation$ids,
  split = "validation",
  model = "random_forest",  # or gradient_boosting / baseline / multinomial_logistic
  feature_set = "time_only", # must match the features actually used
  true_class = as.character(prepared$validation$y),
  predicted_class = prepared$class_levels[
    max.col(P_validation, ties.method = "first")
  ]
)
predictions <- cbind(predictions, probabilities)
result <- evaluate_predictions(
  predictions,
  expected_ids = prepared$validation$ids,
  expected_true_class = prepared$validation$y
)
result$summary
result$per_class
result$ordinal_summary
result$confusion_matrix
```

Run each model separately against the SAME references. Comparison tables can
then use `rbind()` on their summaries. Do not mix feature settings, cause opt-in,
validation cohorts or preprocessing versions. Mark archived-context runs as
retrospective; model names should distinguish experiment variants as needed.

## Executed synthetic verification

From the repository root:

```r
source("moddeling/07_evaluatie/validate_evaluation.R")
```

Or:

```sh
Rscript moddeling/07_evaluatie/validate_evaluation.R
```

56 checks passed. These cover known hand-calculated log loss/accuracy/F1,
recall/support, ordinal offsets, confusion matrix cells and axes, open-ended
subsets, perfect all-class predictions, uniform probabilities, exact zeros,
ties, row preservation, Step 02-style factors, algorithm-independent outputs,
malformed columns/IDs/labels/probabilities, pooled experiments, reference
mismatches, invalid options, default test lock and protected-input preservation.

The four-row synthetic example has log loss 1.334784840, accuracy 0.25,
macro-F1 `(2/3)/102`, within-one-class 75%, underestimation 0.50 and
overestimation 0.25. These are artificial verification results, not model scores.

Only the validation driver writes reports, under `output/`:
`synthetic_validation_checks.csv`, `synthetic_metrics.csv`,
`synthetic_per_class.csv`, `synthetic_confusion_matrix.csv`,
`synthetic_ordinal_summary.csv` and `verification_report.md`.

## Limitations, impact and next steps

- This step reports synthetic tests; actual 2024 baseline/ridge evaluation is
  documented in Steps 03 and 04. No final test performance has been measured.
- The evaluator checks supplied truth against references only when provided;
  it cannot detect an incorrect model row-to-ID attachment from probabilities
  alone. Model scripts must preserve Step 02 row alignment.
- Equal row counts alone do not ensure equal cohorts; supply reference IDs.
- Rare classes and zero probabilities can produce poor or infinite log loss.
  The classifier's missing-class/smoothing policy remains to be agreed; it is
  not silently implemented in evaluation.
- No confidence intervals or paired model significance tests are implemented.
- Class metrics do not estimate passenger delay or causal effects; clean-data
  selection and retrospective-feature limitations continue to apply.
- Baselines and ridge regression are complete in Steps 03 and 04. Oliver supplies
  forest/boosting predictions, using this evaluator unchanged.
- Review by Oliver is pending. No commits, pushes or merges performed.

## Change log

2026-11-11: Implemented shared evaluator and documentation; executed 56
synthetic checks. No real model performance claims.
