# Instructions for AI assistants (and for people using one)

This file is for any LLM working with this repository (Claude Code, Codex, Cursor,
Copilot, ChatGPT…). It explains what the project is, where the truth lives, what you
must **not** do, which misunderstandings are common, and what every folder and file is.

## The project in five lines

- Course BDMA, Part B: at the start of a train disruption, predict the probability of
  each of **102 duration classes** ([0,10), [10,20), …, [1000,1010), ≥1010 minutes).
- Data: Rijden de Treinen, 44,248 selected domestic disruptions 2011–2025.
  Training 2011–2023, validation 2024, test 2025.
- Primary metric: multiclass **log loss** (lower is better).
- Final result (test 2025): time-only survival 3.1620 (baseline 3.2065); context
  random forest 3.0189 (baseline 3.0273). Modest gain, no precise end time.
- Status: modelling and final test **completed**. Remaining: report (max. 5 pages),
  presentation (max. 10 slides) and code submission.

## Read in this order

1. `docs/PROCESS.md`: all steps and decision points, with their reasons.
2. `docs/HANDOVER.md`: exact numbers, limitations, instructions for finishing.
3. `moddeling/09_modelkeuze_en_test/output/B5_FINAL_REPORT_TEXT.md`: the only current report text.
4. `moddeling/README.md`: step overview and reproduction commands.
5. Only when needed: the README of a specific step (see the map below).

## Hard rules

1. **Do not re-run `moddeling/09_modelkeuze_en_test/final_test.R`** and do not delete
   `TEST_OUTCOMES_OPENED.txt`. 2025 has been used once. Never use 2025 to choose or
   tune models, settings or features.
2. **Do not invent numbers.** Every number comes from a file in an `output/` folder.
   Name the source. If something is not in the outputs, say it was not measured.
3. Do not change the target (102 classes), split or primary metric without an
   explicit team decision. Never switch back to binary to show a higher accuracy.
4. `data/disruptions_2011_2025_raw.csv` is never changed. Only
   `Data Cleaning/clean_disruptions.R` writes to `data/`.
5. New model code uses `prepare_data()` (step 02) and `evaluate_predictions()`
   (step 07). Do not modify these shared functions.
6. Do not overwrite the frozen files in `moddeling/09_modelkeuze_en_test/output/`
   (`frozen_manifest.csv`, `*_before_labels.csv.gz`, `prediction_hashes_before_labels.csv`).
7. Commit or push only when the user asks.

## Common misunderstandings

| You see… | It means… |
|---|---|
| Column `long_disruption` (duration > 60) in the data | A leftover of the original binary plan. Not the target and not a predictor. |
| "61,602 disruptions" or "50.7% long" in old notes | Dataset version v1 (Jesse). The current one is v2: 44,248 rows. See PROCESS.md, "How the dataset changed". |
| Data from 2011–2016 | Only 5–16% per year survived cleaning, mostly long infrastructure disruptions. A different population from 2017+ (`Data Cleaning/output/yearly_profile.csv`). |
| Folder numbers 01–15 | Not the execution order. Actual: 01→02→07→03→04→05→06→08→10→11→12→13→09→14→15. |
| "2025 is locked" in a step README | The situation during that step. The final test was run afterwards in step 09. |
| Ordinal advice in `12_modelstrategie/` | Superseded by survival (step 13). Kept as a record of the discussion. |
| 2024 results | Validation, used repeatedly. **Not** an independent test; only 2025 is. |
| Two chosen models (survival and forest) | Two information scenarios (time-only and archived context), not competitors. |
| "Archived context" (cause, route) | The last stored values; they may have been changed after onset. Not proven usable live. |
| Interval width 213.78 min and 222.88 min | Different model and year: context survival on 2024 versus context forest on 2025. |
| "Within one class" | Not the same as "at most 10 minutes off"; the open final class has no midpoint. |
| `start_time` | The moment of the first public NS message (step 15), not the physical start. |
| Logistic regression has the highest accuracy | True (12.76% on validation), but the choice was fixed on log loss in advance. |
| Dutch words in folder names and data values | Folder names were kept because scripts refer to them (glossary below). Data values such as `cause_nl` are source data. All documentation is in English. |

## Glossary of Dutch names

| Dutch | English |
|---|---|
| `moddeling` | modelling (historical spelling) |
| `voorbereiding` | preparation |
| `evaluatie` | evaluation |
| `foutanalyse` | error analysis |
| `modelkeuze_en_test` | model choice and test |
| `regressie_experiment` | regression experiment |
| `historische_kenmerken` | historical features |
| `modelstrategie` | model strategy |
| `bronnenonderzoek` | source research |
| `koppelpilot` | linkage pilot |
| `storing` / `storingen` | disruption(s) |
| `oorzaak` | cause |

## Where to find what

| Question | File |
|---|---|
| All validation scores | `moddeling/13_survival/output/all_model_comparison.csv`, `moddeling/08_foutanalyse/output/validation_comparison.csv` |
| Test scores 2025 | `moddeling/09_modelkeuze_en_test/output/test_summary.csv`, `test_bootstrap.csv` |
| Errors per subgroup (test) | `moddeling/09_modelkeuze_en_test/output/test_groups.csv` |
| Calibration and recovery probabilities | `moddeling/09_modelkeuze_en_test/output/test_calibration.csv`, `test_thresholds.csv` |
| Cleaning filters and counts | `Data Cleaning/output/cleaning_report.md`, `filter_audit.csv` |
| Differences between years | `Data Cleaning/output/yearly_profile.csv` |
| Class definition | `moddeling/01_target/output/classes.csv` |
| Figures for slides | `moddeling/08_foutanalyse/output/*.png`, `moddeling/13_survival/output/probability_diagnostics.png` |

Do not load the large `*_predictions.csv.gz` and `*_before_labels.csv.gz` files into
your context: they hold per-row probabilities (102 columns). Use the summary CSVs.

## Repository map

Every step folder follows the same pattern: a `README.md` (goal, method, results,
checks), R or Python scripts, and an `output/` folder with results. Scripts are run
from the repository root. Typical script roles: `run_*.R` = run the whole step;
`validate_*.R` = automated checks; `*_predictions.csv.gz` = per-row probabilities;
`*_summary.csv` / `validation_comparison.csv` = metrics; `verification_report.md` =
what was checked and with which package versions.

**Root**
- `README.md`: entry point for humans. `AGENTS.md`: this file. `CLAUDE.md`: imports this file for Claude Code.
- `Train-disruptions.Rproj`: RStudio project. `.gitignore`: excludes model caches, local packages and downloads.

**`data/`**
- `disruptions_2011_2025_raw.csv`: source data, never modified (62,540 records).
- `disruptions_2011_2025_clean.csv`: cleaned data used by all models (44,248 rows).

**`Data Cleaning/`** (phase 1)
- `clean_disruptions.R`: raw → clean, 12 filters; writes the clean CSV and `output/`.
- `test_clean_disruptions.R`: checks of the cleaning. `yearly_profile.py`: per-year description.
- `output/cleaning_report.md`: filters, counts, choices and limitations. `filter_audit.csv`:
  rows removed per filter. `excluded_disruptions.csv`: every excluded record with reasons.
  `yearly_retention.csv`, `yearly_profile.csv`: per-year retention and profile.
  `threshold_sensitivity.csv`: effect of other limits.

**`descriptive data analysis/`** (phase 0): `raw_descriptive_analysis.R` and its
summaries/plots of the raw data in `raw_analysis_output/`.

**`docs/`**: `PROCESS.md` (story and decisions), `HANDOVER.md` (numbers and finishing).

**`moddeling/`** (all modelling steps; `README.md` = step table and run order)

| Folder | Contents |
|---|---|
| `01_target/` | `define_duration_classes.R`; `output/classes.csv` (the 102 classes), cutoff candidates and class counts |
| `02_voorbereiding/` | `prepare_data.R` (shared split and preprocessing), `validate_preparation.R`; split counts and checks |
| `03_baselines/` | Global and cause-group frequency baselines; validation predictions and metrics |
| `04_logistic_regression/` | Multinomial ridge regression (glmnet); tuning folds, predictions, confusion matrices, PDF figures |
| `05_random_forest/` | `tree_workflow.R` (shared tuning workflow for tree models), `random_forest.R`, `run_random_forest.R`, `install_dependencies.R`; tuning results and predictions. **Chosen context model** |
| `06_gradient_boosting/` | Multiclass XGBoost with the same workflow; not chosen |
| `07_evaluatie/` | `evaluate.R` (`evaluate_predictions()`: log loss, accuracy, macro-F1, ordinal metrics), synthetic checks |
| `08_foutanalyse/` | `run_error_analysis.R`, `plot_results.R`; comparison of all models, subgroup errors, permutation importance, bootstrap, PNG figures |
| `10_regressie_experiment/` | Direct minute prediction (MAE); not adopted |
| `11_historische_kenmerken/` | `history_features.R` (point-in-time history features), regression with them; no gain |
| `12_modelstrategie/` | README only: strategy review, ordinal proposal (superseded) |
| `13_survival/` | `survival.R` (discrete-time hazard model), `run_survival.R`, `run_recent.R` (2017 variant), `evaluate_survival.R` (calibration, intervals), `verify_predictions.py`; `output/selection_and_uncertainty.md`, `all_model_comparison.csv`. **Chosen time-only model** |
| `09_modelkeuze_en_test/` | `selection_plan.csv` (frozen choice), `TEST_PROTOCOL.md`, `final_test.R` (ran once), `test_diagnostics.R`, `verify_saved_test.py`; `output/` = test predictions, `test_*.csv` metrics, frozen manifest, `FINAL_TEST_REPORT.md`, `B5_FINAL_REPORT_TEXT.md` |
| `14_bronnenonderzoek/` | README only: public sources for extra predictors (NS/NDOV, KNMI, stations) |
| `15_koppelpilot/` | `download.py`, `pilot.py`, `report.py`, `test_pilot.py`; links first NS messages to disruptions on 3 days; `output/PILOT_REPORT.md` |
| `run_oliver.R` | Runs steps 05, 06 and 08 in sequence |

Git-ignored and therefore not in the repository: `output/models/` (fitted models,
rebuilt by the scripts), `.R-library/` (local packages), `data/external/` (pilot
downloads, re-downloaded by `15_koppelpilot/download.py`).

## Without access to the repository (chat LLM)

Upload only these files; nothing more is needed to understand the project:
`AGENTS.md`, `docs/PROCESS.md`, `docs/HANDOVER.md`,
`moddeling/09_modelkeuze_en_test/output/B5_FINAL_REPORT_TEXT.md` and, for exact numbers,
`moddeling/09_modelkeuze_en_test/output/test_summary.csv`.
