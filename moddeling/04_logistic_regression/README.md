# Step 04 — Regularised multinomial logistic regression

Owner: Mart. Reviewer: Oliver.

## Objective and completed status

Implemented and executed two 102-class ridge multinomial models with glmnet:
time_only and archived_context (explicit retrospective cause opt-in).
Shared preparation, target definitions and evaluation were reused unchanged.
Chronological tuning, final 2011–2023 fits, 2024 validation evaluation,
baseline verification, figures and validation checks have been executed.
No 2025 outcomes were accessed or reconstructed. No forest/boosting models
were trained; no branch switch, commit, push or merge was performed.

Existing uncommitted work was preserved on `mart-first-analysis`. No large
fitted models or caches are saved. All Step 04 outputs are under this directory.

## Inputs, dependencies and fixed interfaces

- Clean input: `data/disruptions_2011_2025_clean.csv`, 44,248 rows.
  MD5 `6f22afc6b05fe5e65ed8bd583bc5ba68`.
- Step 01: frozen classes.csv, 102 ordered labels, last interval [1010,+Inf).
  No class merging, recoding or new target selection.
- Step 02: `prepare_data(include_retrospective_cause=TRUE,
  include_test_outcomes=FALSE)`; matrix fields are `train$X$time_only` and
  `train$X$archived_context`, with separate IDs/labels/metadata.
- Step 03: saved comparison CSV and BOTH compressed baseline prediction tables.
  Their shared-evaluator scores and exact validation ID/truth sequences were
  verified against the prepared data before comparison.
- Step 07: `evaluate_predictions()` supplies all metrics and conventions.
- R with glmnet 4.1-10 (installed), Matrix and glmnet's installed dependencies.
  Exact runtime versions are in `output/verification_report.md`. If missing,
  install glmnet with `install.packages("glmnet")` before running.

Protected clean data and every file in Steps 01, 02, 03 and 07 were checked
with before/after hashes and remained unchanged. Validation drivers from those
steps were inspected, not rerun to overwrite their existing outputs.

## Model intuition and likelihood

Each class k has a linear score `b0_k + x %*% beta_k`. A softmax converts all
102 scores into probabilities summing to one. This is a nominal multinomial
classifier, not binary logistic regression or regression on numeric class IDs.
The model does not directly exploit ordinal distances in its likelihood.

The objective is negative multinomial log likelihood plus a ridge penalty on
coefficients (`alpha=0`). Ridge shrinks unstable effects rather than selecting
a sparse subset. Intercepts remain unpenalised. No automatic class weights,
oversampling or shuffled cross-validation are used.

Step 02 matrices are supplied directly. glmnet uses `standardize=FALSE` to avoid
refitting an additional scaling layer. Calendar/route indicators retain shared
encoding; numeric fields use Step 02's training-fitted scaling. An intercept is
included despite redundant calendar indicators; positive ridge regularisation
stabilises the coefficient fit. Interpret individual coefficients cautiously.

### Rare/absent-class and numerical policy

The installed glmnet factor-response path rejects classes with zero or one
observation. We use its supported class-count matrix response and append ONE
pseudo-row at the mean of the retained training feature matrix. That row has
one count in each of the 102 classes, equivalent to 102 fractional observations
with identical training-mean features. All genuine observations retain one unit
of weight; no real rows or rare classes are removed. This supplies a symmetric
training-only Laplace-style prior for the multinomial fit. It is not an
inverse-frequency weighting scheme. The same policy applies to all folds/fits.

This is an explicit model assumption, not an independently agreed universal
policy for every team algorithm. Oliver should review compatibility before
cross-algorithm conclusions. Step 03 uses its own already documented Laplace
baseline; the shared evaluator does not apply smoothing for any model.

After prediction, a FIXED numerical floor 1e-15 is applied and row probabilities
are normalised. This is upstream of the evaluator, which remains unchanged.
It prevents numerical zero probabilities; it is not learned from held-out
labels. It contributes negligible probability mass under ordinary predictions.

Returned glmnet probability class names must EXACTLY match the frozen class
order. Wrong feature columns/order are rejected. No interpolation between
unfitted lambdas, silent missing-class columns or partial convergence is allowed.
Warnings and nonzero convergence codes stop the run for review.

## Features and leakage controls

- time_only uses all 45 shared time predictors, available from start time.
- archived_context uses shared route/station counts, missingness, five hub
  flags, top-20 route indicators and explicitly enabled cause-group encoding.
  The actual column count is recorded per tuning fold because training-fitted
  vocabularies may differ. No independent preprocessing was written.
- End time, duration, binary long_disruption, duration-derived fields,
  statistical causes and IDs never enter model matrices.
- Folds call prepare_data() separately, so scaling, imputation and vocabularies
  are refitted on that fold's retained training records.
- Shared local-time split/boundary protections are retained. Training events
  unfinished at the next validation boundary are excluded by Step 02.
- 2025 outcomes remain locked as NA; no test predictions are generated.

**Archived-context is retrospective.** The saved route/station/cause information
may have changed after onset; improved results would not prove live deployability.

## Tuning design and selected hyperparameters

Small a-priori grid: alpha=0 only; lambda in {0.1, 0.01, 0.001}.
An elastic-net search was not added: the requested ridge reference already
requires 102 class equations per feature set and rare classes favour restraint.
There is no evidence here comparing ridge against elastic net.

Forward folds:

| Training | Fold validation | Training rows | Validation rows |
|---|---|---:|---:|
| 2011–2021 | 2022 | 23,470 | 4,975 |
| 2011–2022 | 2023 | 28,445 | 4,559 |

Both folds had zero temporal-boundary exclusions. Years outside each requested
fold are explicitly excluded by shared preparation. Each feature/lambda candidate
has scores from both years. Selection minimises the equal-year mean log loss;
an exact tie favours stronger regularisation. The fold SD is reported as
variation across years, not a confidence interval. No 2024 scores enter selection.

Mean forward-fold log loss:

| Feature set | Lambda | 2022/2023 mean log loss | SD across years |
|---|---:|---:|---:|
| time_only | 0.100 | 3.278404 | 0.118094 |
| time_only | 0.010 | 3.275314 | 0.116744 |
| time_only | 0.001 | 3.265703 | 0.114936 |
| archived_context | 0.100 | 3.243411 | 0.123742 |
| archived_context | 0.010 | 3.173040 | 0.125385 |
| archived_context | 0.001 | 3.122172 | 0.121620 |

Both variants selected alpha=0, lambda=0.001. This is the weakest penalty tested;
we have not established a global optimum or expanded the search after viewing
2024. Full fold scores and preprocessing/convergence diagnostics are in
`tuning_fold_results.csv`. Final fits use all 33,004 training rows; comparison
uses the same 5,296 validation IDs, with 5,948 test rows held out and locked.

## Actual 2024 validation comparison

Accuracy/under/over are percentages; macro-F1 uses all 102 fixed classes.

| Model | Log loss | Accuracy | Macro-F1 | Within one class | Under | Over |
|---|---:|---:|---:|---:|---:|---:|
| Global baseline | 3.230895 | 11.73% | 0.002058 | 22.85% | 88.27% | 0.00% |
| Cause baseline (retrospective) | 3.071563 | 11.78% | 0.004701 | 27.13% | 82.44% | 5.78% |
| Ridge: time-only | 3.217299 | 11.78% | 0.002700 | 23.51% | 87.73% | 0.49% |
| Ridge: archived-context (retrospective) | 3.082036 | 12.76% | 0.009578 | 27.96% | 77.30% | 9.93% |

Time-only ridge reduces log loss by 0.0136 (0.42%) versus the global baseline:
a small improvement, with very similar accuracy. Archived-context ridge has
higher accuracy and macro-F1, but its log loss is 0.0105 HIGHER than the cause baseline.
It therefore does NOT improve on the relevant retrospective baseline under the
prespecified primary metric. No statistical significance is claimed.
Both ridge models systematically underestimate duration, particularly time-only.
Exact-bin prediction remains difficult; 97 of 102 classes occur in validation.
The final open class remains separate; no class offset is converted into minute error.

## Scripts, output structure and reproduction

- `logistic_regression.R`: reusable `fit_multinomial()`,
  `predict_multinomial()`, `multinomial_prediction_table()` and
  `select_regularisation()`. Sourcing defines functions only.
- `run_logistic_regression.R`: complete tuning, final fitting, evaluation,
  baseline comparison, verification and export workflow.
- `validate_logistic_regression.R`: reusable synthetic and actual-data checks.
- `plot_results.R`: regenerates vector PDF figures from saved summaries without
  fitting models. Two figures: loss comparison and aggregated confusion matrices.
- `output/`: tuning fold/mean/selection tables, final diagnostics, four-model
  comparison, compressed validation predictions, per-class/observation metrics,
  full confusion matrices, ordinal summaries, verification reports and figures.

From the repository root in R:

```r
source("moddeling/04_logistic_regression/run_logistic_regression.R")
```

Or terminal:

```sh
Rscript moddeling/04_logistic_regression/run_logistic_regression.R
```

This executes the models and validation script together; validation checks depend
on the fitted objects held in the runner and do not silently use stale caches.
The deterministic synthetic refit uses seed 42. No large fitted models are saved;
reproduction rebuilds them from source data and settings.

To regenerate figures alone:

```r
source("moddeling/04_logistic_regression/plot_results.R")
```

Figures use English labels and vector PDF output. The confusion view aggregates
classes into six labelled duration groups for readability, keeps 1010+ separate,
and shows percentages within each true group. Model fitting and all metrics
still use the original 102 classes. Full 102x102 tables are also saved.
PNG output is not required: this R installation's Cairo/X11 dependency is missing;
PDF generation succeeds and has no extra graphics-package dependency.

To reuse the models in another controlled training-only experiment:

```r
source("moddeling/02_voorbereiding/prepare_data.R")
source("moddeling/04_logistic_regression/logistic_regression.R")
p <- prepare_data(include_retrospective_cause=TRUE)
model <- fit_multinomial(p$train$X$time_only, p$train$y, p$class_levels,
                         lambdas=0.001, alpha=0)
P <- predict_multinomial(model, p$validation$X$time_only, lambda=0.001)
table <- multinomial_prediction_table(p, P, "time_only")
```

## Executed validation and remaining limitations

31 checks passed in the executed complete workflow, covering:
fixed Step 01 definitions; counts and unique/disjoint IDs; test-outcome lock;
prescribed training-only folds and all twelve candidate evaluations; retained
training fit IDs; convergence; selection reproducibility; rejection of 2024
tuning scores; final training counts and pseudo-row provenance; no forbidden
predictors; 5296x102 finite normalised probabilities; class order/first-maximum
predictions; shared-evaluator ID/truth alignment; actual saved baseline score
verification; synthetic singleton/99-absent-class fitting; deterministic synthetic
refit; rejection of misordered predictors; held-out label isolation; saved
prediction round trips; and protected-input preservation.

The first run emitted PDF font warnings for en-dash labels. Labels were changed
to portable ASCII and figures regenerated successfully with warnings treated as
errors. A final complete workflow was then executed with warnings treated as
errors; see verification_report.md for final runtime and package versions.

Remaining assumptions: small ridge grid with a boundary optimum; symmetric
pseudo-count prior; fixed probability floor; equal-year tuning objective; no
interaction terms, class weighting or elastic-net comparison; highly imbalanced
classes; selected ≤24-hour domestic population and historical filtering changes.
There are no confidence intervals or claims of causal relationships. Coefficients
are conditional, regularised associations across 102 classes, not causal effects;
no individual coefficient interpretation is needed to establish these results.

For Oliver: keep the same feature/cause settings, fold boundaries, validation
IDs, class order and evaluator. Document forest/boosting rare-class probability
handling explicitly; do not assume this pseudo-count model prior automatically
applies to tree algorithms. Compare time-only methods separately from
retrospective methods and report baseline performance even when a more complex
model loses. The shared contract and original baseline results remain unchanged.

## Report text

The combined, final B5 text (including these results) is
`moddeling/09_modelkeuze_en_test/output/B5_FINAL_REPORT_TEXT.md`.

## Change log

2026-11-11: Implemented ridge models, chronological tuning, 2024 predictions,
baseline comparison, vector figures and 31 executed checks. Oliver review pending.
