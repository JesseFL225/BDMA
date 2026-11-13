# Step 13 — Discrete-time survival probabilities

Owner: Oliver; review with Mart. Status: implemented; validation outputs and
selection are in `output/selection_and_uncertainty.md`. Development experiment
before Step 09, not a final test result.

> **Status 13 november 2026:** afgerond. De 2017-variant is gekozen als tijd-only model en daarna getest in [stap 09](../09_modelkeuze_en_test/README.md). Waar hieronder staat dat 2025 "locked" is, beschrijft dat de situatie tijdens deze stap. Procesverhaal: [docs/PROCESVERLOOP.md](../../docs/PROCESVERLOOP.md).

## Question and assignment fit

At disruption onset, predict a probability distribution over the frozen 102
duration classes. This is an additional suitable predictive model for Part B5;
the original assignment requires at least three models, not particular algorithms.
Existing logistic regression, forest and multiclass boosting remain comparators.
Survival probabilities support uncertainty communication and decisions at fixed
time horizons, rather than just one guessed class. No minimum accuracy is promised.

## Model

For interval j, learn h_j(x) = P(T in interval j | T reaches interval j, x).
Then p_j(x) = h_j(x) * product over previous intervals of (1 - h_l(x)).
The final class receives the remaining probability after 101 finite intervals.
Features x are fixed at onset in the time-only experiment; archived-context
availability remains unverified. The interval index is a hypothetical future
time, not the observed duration fed into prediction.

Training expands each disruption into the intervals in which it was at risk.
Finite-class records end in one positive event; records in the >=1010-minute
class contribute 101 non-events and no fabricated terminal event. This is
administrative truncation of the likelihood at the final class boundary; it
does not imply the original dataset contains right-censored observations.

The binomial likelihood across these rows equals the class likelihood for each
original event. Do not shuffle expanded rows into train/validation, rebalance
binary labels or weight each row by inverse episode length: those operations
would change the intended likelihood or introduce leakage. All splitting occurs
before expansion. Uncertainty resamples original calendar days, not period rows.

XGBoost learns hazard corrections using binary logistic loss, histogram trees,
interval index and the same shared features as other models. Training-only
marginal hazards, smoothed by one pseudo-event per class, provide logit offsets.
The same offsets must be supplied at prediction. No proportional-hazards
assumption is imposed; trees may interact features with interval index.

## Frozen tuning and evaluation

Three candidates: depth 2 / 100 rounds, depth 3 / 100 rounds, depth 2 / 250 rounds.
Learning rate .05; min_child_weight 20; lambda 10; full row/column sampling;
two threads; seed 42. Select lowest mean event-level log loss across forward
folds training through 2021 -> 2022 and through 2022 -> 2023. Grid order breaks
exact ties. Refit shared preprocessing inside each fold.

Final training is 2011–2023, validation 2024, identical 5,296 validation IDs and
frozen classes. Both feature sets are assessed independently. The numerical
class-probability floor is 1e-15, followed by normalization, consistent with
existing boosting/logistic outputs; the shared evaluator is unchanged.

A fixed-setting sensitivity model refits on 2017–2023. This was specified before
its 2024 assessment; it is not a separately tuned claim about the best recent
model. Recent settings come from the full-history forward-fold comparison.

## Metrics and interpretation

- Primary: multiclass log loss. Exact-class accuracy is secondary and may rank
  models differently. A lower probability loss is not a guarantee of a more
  accurate single class prediction.
- Ranked probability score: average squared cumulative-probability error over
  101 boundaries. It uses class order; it is not a minute-level error measure.
- At 30, 60 and 120 minutes: probabilities of ending **strictly before** the
  boundary, Brier scores and reliability bins with support. Frozen half-open
  intervals cannot distinguish T < 60 from T <= 60 without finer information.
- Central 80% intervals contain whole classes from the 10th to 90th percentile.
  Report actual coverage, number of classes and width together. Coarse bins can
  produce coverage above 80%; wide intervals may be unhelpful despite covering
  outcomes. Intervals touching the tail have infinite upper bounds, not invented
  midpoints. Finite widths are summarized separately with their frequency.
- These are model-based intervals, with no conformal or coverage guarantee.
  Calibration is evaluated on 2024; no calibration mapping is fitted on it.
- Paired day bootstrap (500 replicates) compares survival variants with forest.
  Intervals are descriptive after development, not independent significance
  tests or adjusted multiple-comparison claims.

## Files and reproduction

Run from the repository root after existing Steps 03–06 have produced their
prediction tables. Reuse the local xgboost/Matrix installation.

```sh
Rscript moddeling/13_survival/run_survival.R
```

`survival.R`: model and risk-set construction. `validate_survival.R`: edge cases,
likelihood identity, marginal-offset reconstruction and prediction invariance.
`run_recent.R`: training-period sensitivity. `evaluate_survival.R`: common
diagnostics, bootstrap, cause/month errors, selection proposal and light-background
figure. All scripts leave test outcomes locked. Model RDS caches are ignored;
shared code, small tables and compressed predictions reproduce the results.

## Limitations and project impact

Survival modelling does not restore information absent from the features. The
clean population excludes durations above 24 hours and inconsistent duration
records; final archive membership is not knowable at onset. Revised causes and
locations make archived-context performance retrospective. These limitations
remain even if log loss improves. No source data or shared preparation/evaluator
is changed by this step.

2024 has already informed development, so the selected model is provisional.
Keep 2025 locked until the specification and selection are frozen for Step 09.
Choose the measured winner rather than the most complicated method. Results
should feed one compact B5 comparison and an uncertainty figure; put equations,
full tuning tables and checks in the appendix/code. No new external data is used.

## Sources and disclosure

- [Discrete-time survival modelling and person-period likelihood](https://bmcmedresmethodol.biomedcentral.com/counter/pdf/10.1186/s12874-022-01679-6).
- [XGBoost DMatrix base margins](https://xgboost.readthedocs.io/en/latest/r_docs/R-package/docs/reference/xgb.DMatrix.html).
- [Rijden de Treinen dataset and reporting changes](https://www.rijdendetreinen.nl/open-data/treinstoringen).

Implemented with AI assistance. The team must be able to explain the likelihood,
comparison and limitations. No commits, pushes or final-test evaluation here.
