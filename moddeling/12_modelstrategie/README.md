# Step 12 — Prediction strategy review

Owner: Oliver, review with Mart. Status: strategy prepared; no new models trained.

Update: after reviewing the original Part B assignment, the agreed technical
extension became discrete-time survival modelling instead of a separate ordinal
model. That experiment is implemented in [Step 13](../13_survival/README.md).
The original proposal below remains a record of the strategy discussion; its
ordinal build recommendation is superseded.

## Objective and evidence

Retain prediction at disruption onset and the agreed 102 ten-minute duration
classes. The earlier supplied project text proposed a binary >60-minute target;
the subsequent user decision supersedes that proposal. Do not silently switch
back to binary classification to obtain a higher accuracy.

Inputs: frozen target and preparation in Steps 01–02, validation comparisons in
Step 08, regression in Step 10, historical-feature experiment in Step 11.
Training has 33,004 events; 61 classes have fewer than 50 examples. A small final
class does not imply that the preceding classes are adequately supported.

On 2024, the cause baseline has log loss 3.0716 versus forest 3.0591, multinomial
logistic 3.0820 and boosting 3.0844. Logistic has the highest exact accuracy among
these context classifiers (12.76%), whereas forest wins log loss. Regression has
MAE 68.06 minutes; added history gives 68.95. These results suggest modest benefit
from the tested feature/model combinations. They do not establish the maximum
predictability of the data or prove that all history features are unhelpful.

## Recommended next experiment: ordered probabilities

Fit a regularized cumulative ordinal model as a challenger to the existing
probability forest and cause baseline. Predict ordered cumulative probabilities
at the fixed ten-minute boundaries and convert their differences into the same
102 class probabilities. Enforce nondecreasing cumulative probabilities and
nonnegative class probabilities summing to one. Prefer a shared-effects model
initially to pool information across thresholds; its proportional-odds assumption
is a limitation to evaluate, not a fact about these data.

This retains class probabilities and exploits order, unlike nominal multiclass
training. It also avoids reducing the entire predictive distribution to one
regression estimate. Better performance is a hypothesis, not a guarantee.

Keep the current two feature sets unchanged for this experiment. Compare models
on the exact same IDs. Use only forward folds within 2011–2023 to tune a small,
predeclared regularization grid. Fit on training and assess 2024 once the grid is
fixed. Earlier folds and 2024 have already informed development: do not describe
them as independent confirmation. Keep 2025 outcomes locked until model selection.

## Evaluation contract

- Keep multiclass log loss as the existing primary selection metric.
- Add ranked probability score (RPS) as an ordered probability diagnostic:
  mean over the 101 boundaries of (predicted cumulative probability minus
  observed cumulative indicator)^2, then mean over events. Lower is better.
- Retain exact accuracy, within-one-class accuracy and per-class support.
  One class of error is not necessarily ten minutes of absolute duration error.
- Derive most-probable class for exact classification; a median class answers a
  different loss function. Label them separately rather than silently changing
  the point-prediction rule.
- Examine probability calibration at prespecified operational thresholds and
  paired calendar-day bootstrap differences. Report subgroup support.
- Never assign a fabricated minute midpoint to the open final class.

Do not change the primary metric after seeing which new model wins. If the group
wants an ordinal score or operational cost to become primary, agree that change
before training and document that it is a revised objective.

## Follow-up priorities, one change at a time

1. Training-period sensitivity: all available training years versus 2017 onward,
   on identical validation cohorts. Refit preprocessing in every training fold.
   The source documents a reporting change in 2017; fewer but more comparable
   observations might help. Do not assume it will.
2. Feature resolution: audit loss of route/station detail from top-20 encoding
   and broad cause groups. Test finer archived causes and route representations
   only as explicitly retrospective experiments unless onset availability is
   verified. Category encoders must fit training only; multivalued routes need
   an explicit representation.
3. Only then consider a categorical boosting challenger such as CatBoost, with
   the same input representation and a bounded chronological tuning budget.
4. External enrichment is conditional on changing the supplied single-dataset
   scope. Prioritize reconstructable initial incident messages, affected scale
   and operational severity; weather is a candidate, not a promised improvement.

## Data and deployment limitations

No algorithm repairs unknown onset availability. Final causes, final affected
routes and outcome-based archive selection limit deployment claims. The >24-hour
filter and duration-consistency exclusions need a separate population-sensitivity
study if the goal becomes prediction for every new incident. Do not remove long
valid incidents simply to improve scores or rewrite the shared clean dataset here.

## Impact, checks and handoff

This review changes no data, targets, fitted models or shared evaluator. No test
outcomes were loaded. The recommended immediate build is the ordinal challenger;
subsequent experiments depend on its evaluation. Results and reproducible code
must be added to a new numbered step when implemented. No commits or pushes in
this step. Prepared with AI assistance.

## Sources

- [Ordinal regression methods](https://jmlr.org/papers/volume18/15-495/15-495.pdf):
  ordered-label modelling foundations.
- [Cumulative probability models](https://www.fharrell.com/post/rpo/): shared
  effects, cumulative probabilities and ordinal-model interpretation.
- [Dataset documentation](https://www.rijdendetreinen.nl/open-data/treinstoringen):
  reporting changes and field definitions.
- [CatBoost categorical features](https://catboost.ai/docs/en/features/categorical-features):
  categorical-input capability, not evidence of superiority on this dataset.
