# Modelling handover, Part B — numbers, limitations and finishing up

Last update: 13 November 2026. Working branch: `Oliver`.
For: Mart and whoever finishes the report, presentation and code submission.

**Reading order**

1. [PROCESS.md](PROCESS.md): the story, all steps and decision points with their reasons.
2. This document: exact numbers, what you may and may not claim, and how to finish.
3. [`moddeling/16_report_inputs/REPORT_INPUTS.md`](../moddeling/16_report_inputs/REPORT_INPUTS.md):
   **the writer's brief**: per report section what to write, with figures and tables.
4. [`moddeling/README.md`](../moddeling/README.md): step overview and reproduction.

---

## 1. Assignment and question

At the start of a disruption we predict the probability of each of 102 duration
intervals ([0,10), [10,20), …, [1000,1010), ≥1010 minutes). One row is one
disruption, not one train journey or one passenger delay.

The original assignment (`Project.pdf`, Part B, pp. 4–6) asks for at least three
suitable predictive models, justified evaluation, error analysis and model choice.
No algorithm, binary target or single data source is required. Submission: a report
of at most 5 pages (excl. appendix/references), access to the exact data, full
analysis code, at most 10 slides. B5 is worth 8 of the 25 points. More complexity
does not automatically earn a higher grade.

## 2. Data, splits and what the models may see

- File: `data/disruptions_2011_2025_clean.csv`, 44,248 disruptions
  (MD5 `6f22afc6b05fe5e65ed8bd583bc5ba68`). Built from the raw data by
  `Data Cleaning/clean_disruptions.R`.
- Split: 33,004 training (2011–2023), 5,296 validation (2024), 5,948 test (2025).
  The from-2017 variant has fewer training rows but the same validation and test IDs.
- Tuning: forward folds through 2021 → 2022 and through 2022 → 2023.
- **Time-only:** hour, weekday, month, weekend, rush hour.
- **Archived context:** additionally cause group, route/station counts, hubs and
  top-20 routes.
- Preprocessing is learned on training only, refitted inside every fold.
  End time, duration, statistical cause and the target are never predictors.
- 2024 was used repeatedly during development. Do **not** call 2024 an independent
  test. 2025 was opened once, after the models were frozen.

## 3. Validation results (2024)

Log loss is the primary metric (lower is better).

| Model | Time-only | Archived context | Exact class (context) |
|---|---:|---:|---:|
| Baseline (global / cause group) | 3.2309 | 3.0716 | 11.78% |
| Multinomial logistic regression | 3.2173 | 3.0820 | **12.76%** |
| Random forest | 3.2139 | **3.0591** | 12.31% |
| Multiclass XGBoost | 3.2195 | 3.0844 | 11.63% |
| Survival, 2011–2023 | 3.1935 | 3.0678 | 11.88% |
| Survival, 2017–2023 | **3.1905** | 3.0627 | 11.86% |

- Logistic wins on exact class, forest on the primary probability metric.
- Forest's extra gain over the cause baseline is limited. Do not claim that complex
  ML brings a large improvement.
- Survival from 2017 clearly wins time-only. The context difference between survival
  and forest is small and uncertain (day-bootstrap interval includes zero).
- Regression (step 10): context MAE 68.06 min versus 78.77 for the median baseline.
  With historical features (step 11) 68.95: no gain.
- Context survival: central 80% intervals cover 90.35%. Among the 97.75% with a
  finite upper bound the mean width is 213.78 minutes. That is not an error of 214
  minutes per prediction and not guaranteed coverage.

Sources: `moddeling/08_foutanalyse/output/`, `moddeling/13_survival/output/`
(`selection_and_uncertainty.md`, `all_model_comparison.csv`).

## 4. Frozen model choice and final test (2025)

Chosen on the lowest validation log loss within each information scenario:

1. **Time-only:** survival from 2017, depth 2, 250 boosting rounds, learning rate 0.05.
   Compared with global frequencies from the same training years.
2. **Archived context:** random forest, 200 trees, minimum node size 100, mtry=sqrt,
   maximum depth 12, 1% blended training prior. Compared with the cause baseline
   (2011–2023).

No retraining on 2024. Hashes recorded in advance; predictions saved before the test
labels were read. Details: `moddeling/09_modelkeuze_en_test/TEST_PROTOCOL.md`.

| Model | Log loss 2025 | Exact class | RPS |
|---|---:|---:|---:|
| Time-only survival from 2017 | **3.1620** | 10.93% | 0.05908 |
| Matching global baseline | 3.2065 | 10.15% | 0.06422 |
| Context random forest | **3.0189** | 12.02% | 0.05048 |
| Matching cause baseline | 3.0273 | 11.79% | 0.05178 |

- Day bootstrap (model − baseline): survival −0.0663 to −0.0246; forest −0.0151 to −0.0012.
- Log loss was lower in 2025 than in 2024, but exact accuracy and RPS got worse.
  So do not write that "all performance improved". The years differ in composition.
- Forest underestimates the class in 83.84% of modal predictions.
- Forest's 80% intervals cover 90.97%; the 98.39% with a finite upper bound are on
  average 222.88 minutes wide.
- The Brier score for "resolved before 60/120 minutes" is slightly worse for forest
  than for the cause baseline. So there is no gain for every decision.

**Decision-level view (added in Step 16 from the saved predictions; extra evaluation,
not selection):** for "ends before 60 min" the AUC is 0.57 for time-only survival,
0.76 for the cause baseline and 0.78 for the forest; Brier 0.239 / 0.184 / 0.185.
Knowing the cause matters far more than the algorithm. The time-only model is
calibrated but barely ranks disruptions (most predictions between 50% and 60%).

**Preferred model for the report: the random forest with archived context.** It has
the lowest validation log loss of all 12 combinations (the rule fixed in advance), beats
its baseline on the test and ranks best. Condition: the cause must come from the first
message (the pilot found a cause in 40/40 first messages, substantively equal to the
final cause in 37/40). Survival is the time-only fallback. Full argument:
`moddeling/16_report_inputs/REPORT_INPUTS.md`, component 5.

Conclusion: a modest gain in overall probability prediction, no reliably precise end
time. The test was independently verified (`verify_saved_test.py`); all 5,948 test
IDs were kept. **Do not tune or select on 2025 anymore.**

Exact numbers for tables and figures: `test_summary.csv`, `test_bootstrap.csv`,
`test_groups.csv`, `test_calibration.csv`, `test_thresholds.csv` in
`moddeling/09_modelkeuze_en_test/output/`.

## 5. Explaining survival simply

For each future interval the model asks: if the disruption has lasted until here,
what is the probability that it ends in this interval? A disruption ending in the
third interval produces two "not yet ended" rows during training, followed by one
"ended" row. That is a reshaping of the same disruption, not extra data.

The conditional probabilities are multiplied into a full duration distribution. The
probability of recovery before 60 minutes is the sum of the first six classes, so
**strictly before** 60 (not "up to and including"). XGBoost learns the interval
probabilities with a binary loss. That is not an ordinary binary prediction "longer
than 60 minutes": the final output is still 102 probabilities. The open final class
receives the remaining probability.

## 6. Linkage pilot of first NS messages (step 15)

Three pre-chosen days (10 November 2017, 2020 and 2023). No model training, no 2024/2025.

- 40 of 42 disruptions were linked one-to-one to a first NS message. There is
  1 ambiguous case and 1 without a valid candidate; both were deliberately rejected
  by rules fixed in advance.
- **Our start moment is the first public message:** `start_time` lies a median of
  1 second from the first NS publication (at most 35 s).
- First cause ≠ final cause in 5 of the 40, of which 3 substantively.
- An NS recovery forecast in the first message: 2/7 (2017), 4/17 (2020), 16/16 (2023).

Use in the report: one or two sentences under limitations or recommendations, or in
the appendix. It is not a model result and not a national percentage. Details:
`moddeling/15_koppelpilot/README.md`. Sources for enrichment:
`moddeling/14_bronnenonderzoek/README.md`.

## 7. Limitations that must stay in the report

- The cleaning excludes, among others, disruptions over 24 hours based on their
  final duration. At onset you cannot recognise that population.
- Many early records were excluded because the duration fields disagree: from
  2011–2016 only 5–16% per year remains, mostly long infrastructure disruptions
  (median 86–158 min versus 42–72 min from 2017). The 2017 sensitivity check
  partly addresses this but does not remove the selection.
  Source: `Data Cleaning/output/yearly_profile.csv`.
- The share of unknown cause rises to 4.6% (2024) and 5.1% (2025), from below 1% in
  2019–2022. The context model therefore gets no cause more often in the validation
  and test years.
- Stored causes and affected routes may have been changed afterwards (confirmed in
  the pilot). Context results are not proven to be usable live.
- We predict at the moment of the first public message, not at the physical start.
- Low exact accuracy and wide intervals limit useful promises to passengers.
- Feature importance is a predictive association, not causal evidence.
- One class off is not the same as at most ten minutes off. The open final class has
  no valid midpoint for minute errors.
- 2024 is not an independent test; only 2025 is.
- All results hold for this data and selection, not automatically for all Dutch
  disruptions or for future registration changes.

## 8. How to finish

**Report** (max. 5 pages). Follow `moddeling/16_report_inputs/REPORT_INPUTS.md` section by
section; reuse wording from `moddeling/09_modelkeuze_en_test/output/B5_FINAL_REPORT_TEXT.md`
where useful. All figures and tables are ready in `moddeling/16_report_inputs/output/`.
Guideline: ~1.5 pages question/data/preparation, ~2 pages models and evaluation
(including the final test), ~1.5 pages errors, recommendations and limitations. Use
one main comparison and one uncertainty or calibration figure. Full grids, subgroups
and checks go to the appendix. Show all model families from validation, not only the
two tested. Make B1 and B3 consistent with the ten-minute classes.

**Presentation** (max. 10 slides): 1 question and stakeholder; 2 data and selection;
3 target and time split; 4 baselines and models; 5 survival intuition; 6 validation
and model choice; 7 final test; 8 errors and uncertainty; 9 limitations;
10 recommendation. Figures: `moddeling/16_report_inputs/output/` (slide-by-slide mapping
in REPORT_INPUTS.md).

**Code.** Submit the repository with the root README as entry point. The single safe
entry point for graders is `Rscript moddeling/run_all.R` (~40 s, no training). Never edit
the files in `frozen_manifest.csv`, not even comments. Model caches
(`output/models/`) are local and Git-ignored; the scripts rebuild them. An unchanged
reproduction is fine, but a new model choice on 2025 is not. `final_test.R` refuses a
second run while `TEST_OUTCOMES_OPENED.txt` exists; do not delete that file.

**Sharing.** Everything is on branch `Oliver`. Open a pull request to `main` and have
Mart review it.

AI was used for code, analysis and documentation. Check the code, make sure the group
can explain the choices and results themselves, and disclose the AI use.
