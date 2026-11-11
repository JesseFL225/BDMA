# Moddeling

Completed: Steps 01 (target), 02 (preparation), 03 (baselines), 04 (ridge multinomial regression), and 07 (shared evaluation). Forest/boosting and final model selection are separate work; no 2025 evaluation has been performed.

Lees ook [het parallelle modellingplan](../docs/parallel_modelling_plan.md).

Data staat in ../data/. Start scripts vanuit de BDMA-hoofdmap. Bewaar code per stap en resultaten onder de output/-submap van die stap. Gebruik dezelfde gedeelde voorbereiding en evaluator.

- [00_afspraken](00_afspraken/README.md): Mart en Oliver
- [01_target](01_target/README.md): Mart, review Oliver
- [02_voorbereiding](02_voorbereiding/README.md): Mart, review Oliver
- [03_baselines](03_baselines/README.md): Mart
- [04_logistic_regression](04_logistic_regression/README.md): Mart
- [05_random_forest](05_random_forest/README.md): Oliver
- [06_gradient_boosting](06_gradient_boosting/README.md): Oliver
- [07_evaluatie](07_evaluatie/README.md): Mart, review Oliver
- [08_foutanalyse](08_foutanalyse/README.md): Oliver, review Mart
- [09_modelkeuze_en_test](09_modelkeuze_en_test/README.md): Mart en Oliver

## Setup and reproduce Mart's completed work

Start R in the BDMA repository root. Base R covers Steps 01, 02, 03 and 07.
Step 04 requires glmnet (verified version 4.1-10) and its dependencies:
```r
install.packages("glmnet") # only if not already installed
source("moddeling/02_voorbereiding/validate_preparation.R")
source("moddeling/07_evaluatie/validate_evaluation.R")
source("moddeling/03_baselines/run_baselines.R")
source("moddeling/04_logistic_regression/run_logistic_regression.R")
```

Run separately or use fresh R sessions for independent reproduction. Scripts
write results under their own output directories. They preserve clean data and
keep 2025 labels unavailable. Step 04 retains the original small ridge grid.

## Shared contract for Oliver

```r
source("moddeling/02_voorbereiding/prepare_data.R")
source("moddeling/07_evaluatie/evaluate.R")
prepared <- prepare_data(include_retrospective_cause = TRUE)
# Use FALSE/default for experiments without archived causes.
# result <- evaluate_predictions(predictions,
#   expected_ids = prepared$validation$ids,
#   expected_true_class = prepared$validation$y)
```

Matrices: `prepared$train$X$time_only` and `$archived_context` (likewise for
validation). IDs and targets are separate; `class_levels` fixes the 102-class
order and `probability_columns` fixes evaluator columns. Use first-maximum
tie handling. Refit prepare_data within each chronological training fold.
The cause-enabled archived-context experiment is retrospective, not proven
real-time deployable. See Steps 02 and 07 for the full API and Steps 03/04
for 2024 baseline/model comparisons. Models must never use duration or end time
as features. Test outcomes remain locked until final model selection.
