# Step 03 — Baseline models

Owner: Mart. Review/handover: Oliver.

## Purpose and completed status

Implemented and executed two training-frequency baselines, scored on 2024
validation only with the unmodified Step 07 evaluator. They provide reference
scores for later multinomial logistic regression, forest and boosting models.
No such advanced models were trained. No 2025 outcomes were imported, evaluated
or used for model selection. No commits, pushes or merges were performed.

## Inputs and shared interfaces

Dependencies: base R and bundled tools only. Run from the repository root.

- Step 02 `prepare_data(include_retrospective_cause = TRUE,
  include_test_outcomes = FALSE)` reads the unchanged clean dataset.
- Training: 33,004 rows with local start years 2011–2023 after Step 02 boundary
  checks. Validation: 5,296 rows from 2024. No main-split exclusions.
- Step 01 supplies the frozen 102 class labels/order and assignment function.
- Step 07 `evaluate_predictions()` computes every metric; there is no second
  evaluator in this step.
- Dataset MD5: `6f22afc6b05fe5e65ed8bd583bc5ba68`.

## Model definitions and fixed smoothing

### Global frequency baseline

For K=102 classes, n training records, and n_k records of class k:

```text
Empirical frequency: n_k / n
Prediction probability: p_k = (n_k + alpha) / (n + K*alpha)
alpha = 1 (Laplace smoothing)
```

Each validation record receives exactly the same probability vector. The label
is the first maximum in the fixed class order. The training modal class is
`0000_0010` (0 to less than 10 minutes). Smoothing gives strictly positive
probabilities even to classes absent in a future training fold. Both empirical
frequencies and smoothed probabilities are exported.

Its evaluator feature_set is `time_only` for the non-retrospective experiment,
but the global baseline deliberately ignores all time features; it uses only
training labels. It is also a reference for archived-context models.

### Cause-group baseline — retrospective only

Let n_gk be training events in group g and class k, and n_g the group's size:

```text
p(k | g) = (n_gk + lambda*p_k) / (n_g + lambda)
lambda = 102 total pseudo-observations, distributed according to global p_k
```

Equivalently this is a weighted average of group empirical frequencies and the
global smoothed training distribution. Small groups shrink more strongly.
The value 102 is a fixed prior mass, NOT 102 observations per class.
Alpha=1 and lambda=102 were chosen before validation scoring; neither was tuned
on 2024 or 2025. They remain assumptions to document, not optimised settings.

Unseen groups receive exactly the global smoothed distribution. Missing groups
use Step 02's `__MISSING__` category: use its learned distribution if it was
observed during training, otherwise fall back globally. The cleaner's `unknown`
label is retained as a distinct category, consistent with Step 02.

`prepared_cause_groups()` decodes Step 02's existing one-hot cause columns using
its fitted vocabulary. It reads no raw cause fields, creates no alternative
encoder, and performs no new imputation. The explicit retrospective opt-in is
required; validation-only causes arrive as `__UNSEEN__` and use the global prior.

**Limitation:** final archived causes may not have been known at disruption onset.
This is a retrospective reference model, not demonstrated real-time performance.
Differences versus the global baseline include access to this extra information.

## Actual 2024 validation results

Metrics below come from the shared evaluator, not manual recalculation.
Accuracy and under/overestimation are displayed as percentages; macro-F1 is on
its original 0–1 scale and includes all 102 classes (unsupported classes score 0).

| Baseline | Log loss ↓ | Accuracy | Macro-F1 | Within one class | Underestimate | Overestimate |
|---|---:|---:|---:|---:|---:|---:|
| Global frequency | 3.230895 | 11.73% | 0.002058 | 22.85% | 88.27% | 0.00% |
| Cause group (retrospective) | 3.071563 | 11.78% | 0.004701 | 27.13% | 82.44% | 5.78% |

The cause baseline reduces log loss by 0.1593 (4.93% relative). It improves
probability quality and adjacent-class accuracy, while exact accuracy remains low.
The global modal prediction is the very first class, so it cannot overestimate
the class and frequently underestimates duration. These are weak reference
models, not evidence that longer durations can be predicted reliably.

Validation includes 97 observed classes; macro-F1 still averages all 102.
Validation records using the unseen/missing-group global fallback: 0.
Class distance is ordinal only, never an exact minute error. The open-ended
1010-plus class is separately reported by Step 07 in ordinal_summary outputs.

## Files and output contract

Scripts:

- `baselines.R`: `fit_global_baseline()`, `predict_global_baseline()`,
  `prepared_cause_groups()`, `fit_cause_baseline()`, `predict_cause_baseline()`
  and `baseline_prediction_table()`. Sourcing defines functions only.
- `validate_baselines.R`: `validate_baselines()` with synthetic and real-data
  integrity checks, including two real chronological folds.
- `run_baselines.R`: sources shared functions, prepares once, fits frequencies,
  produces predictions, uses Step 07, executes checks and exports results.

Prediction files, losslessly compressed to keep them small:

- `output/global_validation_predictions.csv.gz`
- `output/cause_validation_predictions.csv.gz`

Each has 5,296 rows and the exact 108-column evaluator contract:
`rdt_id`, `split`, `model`, `feature_set`, `true_class`, `predicted_class`,
then the 102 `p_...` columns in frozen order. IDs and true classes match the
same prepared validation sequence. Read with `read.csv(path, check.names=FALSE)`.

Other outputs:

- `validation_comparison.csv`: both shared-evaluator summary rows.
- `global_training_distribution.csv`: raw counts, empirical and smoothed values.
- `cause_training_distributions.csv`: group counts and smoothed probabilities.
- `validation_cause_coverage.csv`: group sizes and whether global fallback applies.
- `global_*` / `cause_*` per-class metrics, ordinal summaries and confusion matrices.
- `validation_checks.csv` and `verification_report.md`: executed checks,
  settings, dataset/class hashes and R/package versions.

Only Step 03 files are written. No fitted advanced model or large uncompressed
prediction table is saved. Exact numerical results are in the CSVs.

## Reproduce and reuse

From the repository root, in R:

```r
source("moddeling/03_baselines/run_baselines.R")
```

Or from a terminal:

```sh
Rscript moddeling/03_baselines/run_baselines.R
```

The run sets seed 42; frequency estimation is deterministic and does not need
random sampling. To reuse with chronological folds, call the SAME Step 02
function with new training/validation years, then fit each baseline afresh:

```r
source("moddeling/02_voorbereiding/prepare_data.R")
source("moddeling/03_baselines/baselines.R")
fold <- prepare_data(train_years=2011:2021, validation_years=2022L,
                     include_retrospective_cause=TRUE)
fit <- fit_cause_baseline(
  fold$train$y, prepared_cause_groups(fold,"train"), fold$class_levels
)
P <- predict_cause_baseline(fit, prepared_cause_groups(fold,"validation"))
```

Later model scripts should call the same Step 07 evaluator with expected IDs
and true labels; they should not copy metric calculations from this step.

## Executed verification

35 checks passed in the complete executed run. Coverage:

- Hand-calculated Laplace probabilities, rare/absent classes and positive sums.
- Hand-calculated group shrinkage and unseen/missing cause fallback.
- Decoding the existing Step 02 missing/unseen categories without fitting an encoder.
- Global and conditional class counts match retained training labels exactly.
- Each cause group's counts match its training subset; sums equal global counts.
- Both fits share the same global prior and remain unchanged when held-out
  labels/features are deliberately changed.
- Both models have identical validation IDs/truth, valid probabilities, fixed
  argmax labels, and successful shared-evaluator cohort/truth verification.
- Saved compressed prediction tables were re-read and reproduced the same scores.
- Real forward folds train-through-2021 → 2022 and train-through-2022 → 2023
  refit compatible distributions with positive probabilities and test labels locked.
- Protected clean data and every file under Steps 01, 02 and 07 were unchanged.

No main-split observations were dropped. Forward-fold preparation explicitly
excludes years outside that fold's requested periods using Step 02's audit;
those are intentional fold selections, not silent data cleaning.

## Remaining limitations and next handover

- Cause availability at onset is unverified; this experiment is retrospective.
- Fixed smoothing/shrinkage strengths have not been tuned; any future tuning
  must use training-only chronological folds, not the final test set.
- All classes remain in the contract, even if absent in a fold. These baselines
  now have an explicit positive-probability policy; other algorithms still need
  their own agreed training-only handling consistent with the shared evaluator.
- Strict data cleaning selects domestic disruptions with final duration ≤24h;
  these validation scores do not establish performance on all new disruptions.
- No uncertainty intervals or statistical superiority claims are supplied.
- Step 04 now provides multinomial logistic regression using the same splits
  and evaluator; Oliver can compare forest/boosting against both sets of references.
- Step 02, Step 07 and their original verification reports remain untouched.

## Change log

2026-11-11: Implemented and ran both baselines on 2024 validation; 35 checks
passed. No 2025 outcome access, advanced training or Git publishing performed.
