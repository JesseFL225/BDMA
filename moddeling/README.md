# Moddeling — step overview and reproduction

(The folder name `moddeling` is historical and deliberately not renamed; many scripts refer to it.)

The story behind these steps, with every decision point and its reason, is in
[docs/PROCESS.md](../docs/PROCESS.md). Numbers and finishing instructions are in
[docs/HANDOVER.md](../docs/HANDOVER.md). A file-by-file map is in [AGENTS.md](../AGENTS.md).

Status 13 November 2026: **all steps completed, final test on 2025 done.**
Where a step README still says 2025 is "locked", it describes the situation during that step.

## Steps in execution order

Folder numbers were assigned in advance; experiments 10–13 were added later and run
before the final test (09).

| Order | Folder | What | Owner | Outcome |
|---:|---|---|---|---|
| 1 | [01_target](01_target/README.md) | 102 ten-minute classes, final class ≥ 1010 | Mart | Fixed target |
| 2 | [02_voorbereiding](02_voorbereiding/README.md) (preparation) | Shared split and preprocessing (`prepare_data()`) | Mart | Contract for all models |
| 3 | [07_evaluatie](07_evaluatie/README.md) (evaluation) | Shared evaluator (`evaluate_predictions()`) | Mart | Contract for all models |
| 4 | [03_baselines](03_baselines/README.md) | Global and cause-group frequencies | Mart | Lower bound |
| 5 | [04_logistic_regression](04_logistic_regression/README.md) | Multinomial ridge regression | Mart | Highest exact context accuracy |
| 6 | [05_random_forest](05_random_forest/README.md) | Probability forest | Oliver | **Chosen context model** |
| 7 | [06_gradient_boosting](06_gradient_boosting/README.md) | Multiclass XGBoost | Oliver | Not better than forest |
| 8 | [08_foutanalyse](08_foutanalyse/README.md) (error analysis) | Comparison, subgroups, importance, figures | Oliver | Forest wins validation |
| 9 | [10_regressie_experiment](10_regressie_experiment/README.md) | Duration directly in minutes | Oliver | Not adopted |
| 10 | [11_historische_kenmerken](11_historische_kenmerken/README.md) (historical features) | Earlier disruptions as features | Oliver | No gain, not adopted |
| 11 | [12_modelstrategie](12_modelstrategie/README.md) (strategy) | Ordinal proposal | Oliver | Superseded by survival |
| 12 | [13_survival](13_survival/README.md) | Discrete-time survival, 2017 sensitivity, uncertainty | Oliver | **Chosen time-only model** |
| 13 | [09_modelkeuze_en_test](09_modelkeuze_en_test/README.md) (model choice and test) | Freeze choice, test 2025 once | Oliver and Mart | **Final result** |
| 14 | [14_bronnenonderzoek](14_bronnenonderzoek/README.md) (source research) | Public sources for extra features | Oliver | Research only |
| 15 | [15_koppelpilot](15_koppelpilot/README.md) (linkage pilot) | Link first NS messages (3 days) | Oliver | 40/42 linked; no model |
| 16 | [16_report_inputs](16_report_inputs/README.md) | All report figures/tables, writer's brief, code guide | Oliver | **Start here for the report** |

Before these: `../Data Cleaning/` (raw to clean data) and `../descriptive data analysis/`
(exploration of the raw data).

## Rules for all steps

- Run scripts from the repository **root**.
- Code lives in the step folder, results in that step's `output/`.
- Only `Data Cleaning/` writes to `data/`. Model scripts only read.
- Every model step uses `prepare_data()` (02) and `evaluate_predictions()` (07).
  Nobody builds their own variant.
- Seed 42. Chronological splits; tuning on the folds through 2021 → 2022 and through 2022 → 2023.
- Two feature sets: `time_only` and `archived_context` (retrospective, not proven live).
- Duration, end time and statistical cause are never predictors.
- Fitted models go to `output/models/` (Git-ignored); the scripts rebuild them.

## Using the shared contract (for new model code)

```r
source("moddeling/02_voorbereiding/prepare_data.R")
source("moddeling/07_evaluatie/evaluate.R")
prepared <- prepare_data(include_retrospective_cause = TRUE)  # FALSE = time-only
result <- evaluate_predictions(predictions,
  expected_ids = prepared$validation$ids,
  expected_true_class = prepared$validation$y)
```

Matrices are in `prepared$train$X$time_only` and `$archived_context` (likewise for
validation). `class_levels` fixes the order of the 102 classes. See the READMEs of
steps 02 and 07 for the full API.

## Reproducing

**Safe single entry point (use this):**

```sh
Rscript moddeling/run_all.R    # ~40 s: frozen-hash check, all checks, report inputs; no training
```

The commands below retrain models. Retraining steps 05 and 13 overwrites model files
that are frozen for the 2025 test, so only do that in a separate copy of the repository.

R 4.4–4.5. Base R is enough for steps 01, 02, 03 and 07. Also needed: `glmnet`
(step 04, verified 4.1-10), `ranger` and `xgboost` (steps 05, 06, 08, 10, 11, 13).
Python 3 (standard library) for the verification scripts and step 15.

```sh
# 0. Packages (optional; installs ranger/xgboost into the Git-ignored .R-library/)
Rscript moddeling/05_random_forest/install_dependencies.R

# 1. Data (only needed to rebuild the clean CSV)
Rscript "Data Cleaning/clean_disruptions.R"
python3 "Data Cleaning/yearly_profile.py"

# 2. Shared basis, baselines and logistic regression (Mart)
Rscript moddeling/02_voorbereiding/validate_preparation.R
Rscript moddeling/07_evaluatie/validate_evaluation.R
Rscript moddeling/03_baselines/run_baselines.R
Rscript moddeling/04_logistic_regression/run_logistic_regression.R

# 3. Tree models and error analysis (Oliver); uses the outputs of steps 03/04
Rscript moddeling/run_oliver.R        # = steps 05, 06 and 08 in sequence

# 4. Development experiments
Rscript moddeling/10_regressie_experiment/run_regression.R
Rscript moddeling/11_historische_kenmerken/run_history_regression.R
Rscript moddeling/13_survival/run_survival.R
python3 moddeling/13_survival/verify_predictions.py

# 5. Final test: do NOT re-run. Only verify the saved results:
python3 moddeling/09_modelkeuze_en_test/verify_saved_test.py

# 6. Linkage pilot (the first command needs internet; 12 small files)
python3 -u moddeling/15_koppelpilot/download.py
python3 moddeling/15_koppelpilot/test_pilot.py
python3 moddeling/15_koppelpilot/pilot.py
python3 moddeling/15_koppelpilot/report.py
```

Preferably use a fresh R session per step. Retraining the trees and the survival model
can take a long time. `final_test.R` refuses to run once
`09_modelkeuze_en_test/output/TEST_OUTCOMES_OPENED.txt` exists; do not delete that
file. After retraining, model-file hashes can differ even when predictions are
identical. Do not overwrite the frozen provenance in step 09.
