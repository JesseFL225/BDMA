# Report inputs — everything needed to write the Part B report

For: whoever writes the report and the deck. All modelling is finished. This file
gives, per assignment component (Project.pdf, Part B, §1–6), **what to say, which
numbers to use and which figure or table supports it**. Every number below comes from
a file in `output/` (regenerate with `Rscript moddeling/16_report_inputs/make_report_inputs.R`)
or from the step folders named. Do not add numbers that are not in these files.

Page budget (max. 5 pages excl. appendix and references):
§1–2 data 0.75 · §3 objective 0.5 · §4 preparation and descriptives 1 ·
§5 modelling 1.75 · §6 insights 1. Figures count towards the pages; use at most 4 in
the main text (suggested: fig1 or fig2, fig3, fig5, fig6) and put the rest in the appendix.

**Put the dataset link at the very top of the report:**
https://github.com/JesseFL225/BDMA (data in `data/`; raw source: Rijden de Treinen,
https://www.rijdendetreinen.nl/open-data/treinstoringen, CC BY 4.0).

---

## Component 1 — Data selection (rubric: dataset selection, 3 pts)

- Source: Rijden de Treinen open data on Dutch train disruptions, 2011–2025, 62,540 records.
- Why suitable: clear unit (one disruption), a clear target (duration), a societal
  context (millions of train journeys), and it needs real preparation (inconsistent
  durations, international routes, missing causes/stations, a 2017 registration change).
- **Disclosure (required, otherwise counts as plagiarism):** state which existing
  analyses were consulted. Suggested text: *"We consulted the dataset documentation and
  the yearly disruption statistics published by Rijden de Treinen. We did not use
  existing notebooks or models for this dataset. AI assistants were used for coding,
  analysis support and documentation; all choices were reviewed by the group."*
  Adjust if team members consulted anything else.

## Component 2 — Data description (dataset description, limitations, biases)

- One row = one disruption (not a train journey, not a passenger delay).
- Main raw variables: start/end time, duration, affected routes and stations, cause
  (Dutch text and a broad cause group). Raw-variable dictionary:
  `descriptive data analysis/raw_analysis_output/variable_dictionary.csv`.
- **Data dictionary of the variables used: `output/table1_feature_dictionary.csv`**
  (12 feature groups; marks which are known at onset).
- **Stakeholder and decision:** NS / ProRail traveller information (and, indirectly,
  travellers). Decision: what to communicate at the first disruption message, e.g. "this
  disruption will very likely last longer than an hour, consider an alternative route".
- **Limitations and biases** (keep all of these; details in `docs/HANDOVER.md` §7):
  1. Selection bias from cleaning: > 24-hour disruptions removed on their *final* duration.
  2. 2011–2016 is a different population: only 5–16% of records kept per year, mostly long
     infrastructure disruptions (median 86–158 min vs 42–72 min from 2017). Fig 2.
  3. The stored cause is the *last* recorded cause and may be revised after onset.
     Pilot (step 15): on 40 linked disruptions the first cause differed from the final one
     5 times, 3 substantively.
  4. "Unknown cause" rises to 4.6% (2024) and 5.1% (2025), from below 1% in 2019–2022.
  5. Our start time is the moment of the first public NS message, not the physical start.

## Component 3 — Business objective and predictive goal (3 pts)

- **Objective:** better traveller information at the start of a disruption.
- **Predictive question:** *at the first message of a disruption, what is the
  probability that it ends in each 10-minute interval (0–10, 10–20, …, ≥ 1010 min)?*
- **Why a distribution (102 classes) and not one yes/no question:** one distribution
  answers every operational question without retraining: P(resolved within 30, 60 or
  120 minutes), the most likely interval, or an 80% range. A binary model answers one
  fixed question only. (History: we started from "longer than 60 minutes" and moved to the
  distribution; see `docs/PROCESS.md`, decision 2.)
- **How the stakeholder uses it:** communicate "P(resolved within 60 min) = 25%" style
  messages, or flag likely long disruptions so travellers reroute early.
- **Consequences of errors:** underestimating a long disruption makes travellers wait
  instead of rerouting (costly); overestimating makes them reroute unnecessarily (smaller
  cost). Our models underestimate the modal class in 84–88% of test cases (Table 4), so
  modal predictions should not be communicated as end times; use probabilities.

## Component 4 — Data preparation and descriptive analysis (5 pts)

**Preparation (cleaning):** 12 filters, 62,540 → 44,248 rows
(`Data Cleaning/output/cleaning_report.md`, `filter_audit.csv`). Largest: duration
fields disagree by > 1 min (11,031), foreign route (5,078), unclassifiable route (999),
duration > 24 h (344). Principle: exclude, never invent a corrected label.

**Missing values:** missing station/cause stay NA with explicit indicator features
(`stations_missing`, `routes_missing`, `cause_missing`); missing `cause_group` becomes
"unknown"; numeric gaps are median-imputed on training data only. No rows are dropped
just for having NA.

**Leakage prevention:** chronological split (train 2011–2023, validation 2024, test
2025); preprocessing learned on training only and refitted per fold; duration, end time
and statistical cause are never features; two information scenarios (time-only versus
archived context) because the stored cause may be revised.

**Descriptive results to show (pick 2–3):**
- **Fig 1 `fig1_duration_distribution.png`:** median 51 min; 45.1% last over 60 min;
  7.0% over 300 min; 1.02% in the final class (≥ 1010 min). Message: strongly
  right-skewed, so exact prediction is hard and the long tail matters.
- **Fig 2 `fig2_yearly_shift.png`:** the 2017 break (share kept and median duration).
  Message: why we also trained from 2017.
- **Table 2 `table2_cause_groups.csv`:** cause groups differ enormously in duration:
  rolling stock 41.7% of disruptions, median 27 min, 23% over 60 min; infrastructure
  25.0%, median 111 min, 71% over 60 min; staff 1.2%, median 481 min, 94% over 60 min.
  Message: cause is the key piece of information (this foreshadows the main finding).

## Component 5 — Predictive modelling and performance (8 pts, the biggest item)

**Models (6 families, all on identical rows):**

| Model | Why included |
|---|---|
| Global frequency baseline / cause-group baseline | Benchmarks: is any model better than "historical frequencies"? |
| Multinomial ridge logistic regression | Interpretable linear multiclass model |
| Random forest (probability forest) | Non-linear effects and interactions, robust with little tuning |
| Multiclass XGBoost | Boosting alternative to the forest |
| Discrete-time survival boosting | Uses the order of the intervals; consistent recovery probabilities |

Each model was run in two scenarios: **time-only** (calendar features) and **archived
context** (plus cause group, routes, stations). Tuning: small fixed grids on forward
folds (train ≤ 2021 → 2022, ≤ 2022 → 2023). Selection on 2024 validation. Survival was
also trained from 2017 only (sensitivity to the 2017 break).

**Performance measures (and why):**
- Primary: multiclass **log loss**, fixed in advance; judges the whole probability distribution.
- Secondary: exact-class accuracy, within-one-class, RPS (ordinal error).
- Decision level (stakeholder view): Brier score and AUC for "ends before 30/60/120 min",
  calibration, 80% interval coverage and width.
- Intuitive translation of log loss: exp(−log loss) = the average (geometric-mean)
  probability the model gives to what actually happened. Uniform guessing = 0.98%.

**Validation 2024 (Table 3, Fig 3 `fig3_validation_comparison.png`):**
- Time-only: survival from 2017 is best (gain over baseline 0.0403), then survival
  2011–2023 (0.0374), forest (0.0170), logistic (0.0136), XGBoost (0.0114).
- Context: random forest is best (3.0591; gain 0.0125 over the cause baseline). Logistic
  and XGBoost are *worse* than the simple cause baseline. Logistic has the highest exact
  accuracy (12.76%), but the selection rule was log loss.

**Frozen choice, then one final test on 2025 (Table 4, Fig 4):**

| Model (test 2025) | Log loss | Avg. prob. on true class | Gain vs baseline (95% CI) | Exact class |
|---|---:|---:|---|---:|
| Time-only baseline | 3.2065 | 4.05% | – | 10.15% |
| Time-only survival | 3.1620 | 4.23% | 0.0445 (0.0246 to 0.0663) | 10.93% |
| Cause baseline | 3.0273 | 4.84% | – | 11.79% |
| Context random forest | 3.0189 | 4.89% | 0.0083 (0.0012 to 0.0151) | 12.02% |

Both models beat their baseline on the untouched test year; the intervals exclude zero.

**Decision-level results (Table 5, Fig 5 `fig5_information_vs_algorithm.png`), "ends before 60 min":**

| Model | Brier (lower better) | AUC (higher better) |
|---|---:|---:|
| Time-only baseline | 0.2458 | 0.500 |
| Time-only survival | 0.2392 | 0.572 |
| Cause baseline | 0.1844 | 0.760 |
| Context random forest | 0.1852 | 0.777 |

**Main insight: information matters more than the algorithm.** Adding the cause lifts
the AUC from 0.57 to 0.76–0.78 and cuts the Brier score by about 23%. On top of the cause,
the forest adds only a little: better ranking (AUC +0.017) and log loss, equal Brier.

**Preferred model and why (rubric asks for this explicitly):**
the **random forest with archived context**.
1. It has the lowest validation log loss of all 12 model/scenario combinations: the
   selection rule fixed before any test data were seen.
2. On the untouched 2025 test it beats the cause baseline (interval excludes zero), has
   the best RPS and the best AUC at every threshold, and its probabilities are well
   calibrated (Fig 6 `fig6_calibration_60min.png`).
3. **Condition for use:** the cause must be available at the first message. The pilot
   (step 15) shows the first NS message contains a cause for 40/40 linked disruptions, and
   it matched the final cause substantively in 37/40. Retraining on first-message causes is
   the recommended next step.
- The **time-only survival model** is the fallback when no cause is known. It is
  calibrated and beats its baseline, but it barely distinguishes short from long
  disruptions (AUC 0.57; most predictions between 50% and 60%), so its practical value is low.

**Important prediction errors (discuss these):**
- Modal predictions underestimate the duration class in 84% (forest) to 88% (survival)
  of test cases; long disruptions are systematically underestimated.
- Exact 10-minute class is right only 11–12% of the time; within one class 22–26%.
- 80% intervals cover about 91% of outcomes but are 223 (forest) to 236 (survival)
  minutes wide on average: no precise end times.
- By cause (forest, test): worst for engineering work (log loss 3.92), infrastructure
  (3.77) and accidents (3.56); best for rolling stock (2.54). Source:
  `moddeling/09_modelkeuze_en_test/output/test_groups.csv`.

## Component 6 — Insights, conclusions, recommendations (3 pts)

- **Goal achieved?** Partly. The models give calibrated probabilities that beat the
  baselines on an untouched year, but they cannot promise a precise end time.
- **Insight:** knowing the cause is worth far more than a more complex algorithm.
- **Recommendations for NS / ProRail:**
  1. Communicate probabilities ("likely over an hour"), not exact end times.
  2. Record a structured cause at the first message; that is where most of the
     predictive value comes from.
  3. Use the forest (or even the cause-frequency table) for "will this take more than an
     hour?" style advice; do not use the time-only model for individual advice.
  4. Next step: retrain on first-message causes and the first NS recovery forecast, and
     test on a new, untouched period (2026).
- **Limitations:** the five listed under component 2, plus: 2024 was used repeatedly
  during development (only 2025 is an independent test), and feature importance is
  associational, not causal.

---

## Presentation deck (max. 10 slides, 3 pts)

1. Question and stakeholder (traveller information at the first message)
2. Data and cleaning (62,540 → 44,248; fig 2)
3. Target: a distribution over 10-minute intervals (fig 1)
4. Setup: two information scenarios, chronological split, log loss
5. Models compared (the six families)
6. Validation results (fig 3)
7. Final test 2025 (fig 4 + table 4)
8. Information beats algorithm (fig 5)
9. Errors, uncertainty and limitations (fig 6, 80% interval width, underestimation)
10. Recommendations

## Appendix candidates (outside the 5 pages)

Full validation table (table 3), feature dictionary (table 1), cleaning filter table,
test protocol (`moddeling/09_modelkeuze_en_test/TEST_PROTOCOL.md`), the regression and
historical-feature experiments (steps 10–11, both not adopted), the linkage pilot
(step 15), subgroup errors, and the AI-use statement.
