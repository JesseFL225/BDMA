# Step 16 — Report inputs and code guide

Owner: Oliver. Status: completed 13 November 2026. No model was trained and no model
choice was changed; this step only reads saved results.

## What is here

- **[REPORT_INPUTS.md](REPORT_INPUTS.md): start here if you write the report or deck.**
  Per assignment component: what to write, which numbers, which figure or table.
- `make_report_inputs.R`: builds every report table and figure from saved outputs, in
  report order. It also re-computes the final-test log loss and Brier scores from the raw
  saved predictions and checks they match Step 09 exactly (18 checks, `output/checks.csv`).
- `output/`: figures (`fig1`–`fig6`, PNG, 200 dpi) and tables (`table1`–`table5`, CSV).

| File | Report section | Shows |
|---|---|---|
| `table1_feature_dictionary.csv` | 2 Data description | Every feature group, its source column, meaning, and whether it is known at onset |
| `fig1_duration_distribution.png` | 4 Descriptives | Duration distribution in the 10-minute target classes |
| `fig2_yearly_shift.png` | 4 Descriptives | The 2017 break: share kept and median duration per year |
| `table2_cause_groups.csv` | 4 Descriptives | Size and duration per cause group |
| `table3_validation_models.csv`, `fig3_validation_comparison.png` | 5 Modelling | All 6 model families × 2 scenarios on 2024, as gain over the baseline |
| `table4_test_results.csv`, `fig4_test_gain_over_baseline.png` | 5 Modelling | Final test 2025 with bootstrap intervals and intuitive translation |
| `table5_test_decision_level.csv`, `fig5_information_vs_algorithm.png` | 5–6 | Brier and AUC for "ends before 30/60/120 min" |
| `fig6_calibration_60min.png` | 5 Modelling | Are the predicted probabilities honest? |

```sh
Rscript moddeling/16_report_inputs/make_report_inputs.R   # < 1 minute, base R only
Rscript moddeling/run_all.R                               # all checks + this step, ~40 s
```

## New diagnostics added in this step

AUC and the spread of P(ends before T) were not computed before. They are computed from
the **saved** predictions of the **frozen** models and are labelled as additional
evaluation, not model selection. They revealed that the time-only survival model barely
ranks disruptions (AUC 0.57 at 60 min; most predictions between 50% and 60%), while the
cause information lifts AUC to 0.76–0.78. That is why REPORT_INPUTS.md presents the
random forest (lowest validation log loss overall, i.e. the pre-specified rule) as the
preferred model, conditional on the cause being known at the first message.

## Code guide: how the modelling code fits together

The files below are **frozen for the 2025 test** (listed with their hashes in
`moddeling/09_modelkeuze_en_test/output/frozen_manifest.csv`). They must stay
byte-identical, even comments, so this explanation lives here instead of in the code.

- `02_voorbereiding/prepare_data.R`, `prepare_data()`: reads the clean CSV, assigns the
  102 classes, splits chronologically, builds the two feature sets and learns all
  preprocessing (categories, top-20 routes, medians, scaling) on the training rows only.
- `07_evaluatie/evaluate.R`, `evaluate_predictions()`: checks a prediction table
  (IDs, labels, 102 probabilities that sum to 1) and computes every metric.
- `05_random_forest/tree_workflow.R`, `run_tree_workflow()`: the shared training
  procedure for the forest, XGBoost and survival models. A model only supplies a fit
  function, a predict function and a small grid; the workflow then:
  1. **Tuning:** fits each candidate on 2011–2021 → scores 2022, and on 2011–2022 →
     scores 2023 (forward folds, preprocessing refitted per fold);
  2. **Selection:** picks the lowest mean log loss over the two folds, per feature set;
  3. **Final fit:** retrains on 2011–2023, scores 2024, saves predictions, metrics and
     the model;
  4. **Self-checks:** the reloaded model and the saved CSV must reproduce the predictions
     and metrics, and the data and other steps' files must be unchanged.
- `05_random_forest/random_forest.R`: ranger probability forest (200 trees), blended with
  1% training-class frequencies so no class gets probability zero.
- `13_survival/survival.R`: discrete-time survival. `risk_rows()` expands each disruption
  into one row per 10-minute interval it survived plus one "ended" row;
  XGBoost learns P(ends in this interval | still running); `hazard_to_probability()`
  multiplies these back into the 102 class probabilities.
- `09_modelkeuze_en_test/final_test.R`: the one-time test (do not re-run).

Scripts that are **not** frozen may be edited freely, but run `Rscript moddeling/run_all.R`
afterwards: its first step checks that every frozen file still matches its recorded hash.
