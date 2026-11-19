# Writing guide for B2–B5

This is not finished report text. For each step it lists what the report has to cover,
so you can write it in your own words:

- **Must mention**: needed to meet the rubric. Leaving it out costs points.
- **If there is room**: makes the section stronger. Add it when the page count allows.
- **Avoid**: claims that are wrong or that a grader will penalise.
- **Use**: the figure or table that supports the section.
- **Sources**: where every number comes from. Do not use numbers that are not here.

Page budget for the whole report (max. 5 pages excl. appendix): B1 0.5 · B2 0.5 ·
B3 0.5 · B4 1.25 · B5 1.75 · B6 0.5–0.75. Your B1 and B6 drafts already fit this.
Main-text figures/tables suggested: Figure 1 and Table 1 in B4, Table 2 and Figure 3
in B5. Everything else goes in the appendix you already drafted (A–E).

All figure and table files are in `moddeling/16_report_inputs/output/`.

---

## B2. Data description

Rubric: *dataset selection, description, limitations and potential biases*, 3 points
(shared with B1). The assignment asks for: what the data represent, the main variables,
the stakeholder and the decision, limitations and biases, and a concise data dictionary.

### Must mention

1. **Unit of observation.** One row = one reported disruption on the Dutch rail network.
   Not a train journey and not a passenger delay.
2. **Main variables.** The raw file has 15 columns. The important ones:
   - start and end time, and the duration in minutes (the target is derived from these);
   - affected routes (`rdt_lines_id`) and stations (`rdt_station_codes`);
   - the cause as Dutch and English text (`cause_nl`, `cause_en`);
   - a broad cause group with 9 categories (rolling stock, infrastructure, external,
     accidents, engineering work, logistical, staff, weather, unknown).
3. **Data dictionary.** Refer to Appendix A. Table A1 (variables the models use) is
   already in your draft. Add Table A2 (raw columns, at the bottom of this file).
4. **Stakeholder.** The traveller-information function of NS and ProRail, and through
   them the traveller.
5. **Decision.** What to tell passengers at the first disruption message: wait, or
   take another route.
6. **Limitations and biases.** Name all five; one or two sentences each:
   1. *Selection on the outcome.* Disruptions over 24 hours (344 records) were removed
      based on their final duration, which is unknown at the start. Results only hold
      for disruptions that end within a day.
   2. *Two populations.* 2011–2016: only 5–16% of records per year kept, mostly long
      infrastructure disruptions (median 86–158 min). From 2017: 83–93% kept, median
      42–72 min. Registration practice changed around 2017.
   3. *The cause may be revised.* The stored cause is the last recorded one. Pilot:
      in 5 of 40 linked disruptions the first cause differed from the stored cause,
      3 of them in substance.
   4. *More unknown causes recently.* Below 1% in 2019–2022, 4.6% in 2024 and 5.1% in
      2025 (exactly the validation and test years).
   5. *Scope and timing.* Only publicly reported, domestic disruptions. "Start" = the
      first public NS message, not the physical start of the problem.

### If there is room

- Why this dataset needed real preparation: inconsistent duration fields, foreign
  routes, missing stations (link to B4).
- Statistical cause (`statistical_cause_nl/_en`) exists but is assigned afterwards, so it
  is never a predictor.
- COVID years (2020–2021) are in the training data. Their median duration (42 and 44
  min) is in the same range as 2019 and 2022 (44 and 42 min).
- Today's first message rarely contains a reliable expected duration; that is the gap
  this analysis addresses.

### Avoid

- "61,602 disruptions" or "50.7% long": old dataset version. The current numbers are
  62,540 raw and 44,248 clean.
- Calling the cause "known at the start". It is the *archived* cause.
- Mentioning `long_disruption` as the target. It is a leftover from the first plan.

### Use

- Appendix A, Tables A1 and A2. Figure 2 (B4) supports limitation 2.

### Sources

`descriptive data analysis/raw_analysis_output/variable_dictionary.csv` (15 columns,
9 groups, missing %); `Data Cleaning/output/cleaning_report.md` (344);
`Data Cleaning/output/yearly_profile.csv` (retention, medians, unknown cause per year);
`moddeling/15_koppelpilot/output/PILOT_REPORT.md` (5/40) and `docs/HANDOVER.md` §6
(3 substantive).

---

## B3. Business objective and predictive analytics goal

Rubric: *business objective and predictive analytics goal*, 3 points. The assignment
asks for: one specific objective, **one** focused predictive question, what is
predicted, how the stakeholder uses it, why it is useful, and the consequences of
prediction errors.

### Must mention

1. **Objective.** Give travellers a realistic expectation of how long a disruption will
   last, at the first public message, so they can decide early to wait or reroute.
2. **The predictive question, stated once and exactly.** At the moment of the first
   public NS message, what is the probability that the disruption ends in each
   ten-minute interval: 0–10, 10–20, …, 1000–1010 minutes, or 1,010 minutes and longer
   (102 classes)?
3. **Why a distribution and not yes/no.** One distribution answers every operational
   question: P(over within 30 / 60 / 120 min), the most likely interval, or an 80%
   range. A binary model answers one fixed threshold only.
4. **How the stakeholder uses it.** Turn the probabilities into a message such as
   "likely longer than an hour, consider another route". NS/ProRail choose the threshold;
   we report performance at 30, 60 and 120 minutes (B5).
5. **Why it is useful.** Earlier rerouting by travellers. Fewer people waiting on the
   platform for a disruption that will last hours.
6. **Consequences of errors, and that they are not equal.**
   - *Long predicted as short:* travellers wait, miss connections, reroute too late.
     Worse error.
   - *Short predicted as long:* unnecessary detour. Smaller cost.
   - Our models make the worse error more often: they underestimate the duration class
     in 84–88% of test cases (B5). So the prediction should be communicated as a
     probability, not as an end time.
7. **Link to the metric.** Log loss penalises a confident wrong forecast much more than
   an honest uncertain one. That matches the cost of false reassurance.

### If there is room

- That the first plan was binary (> 60 min) and why it changed (one fixed question,
  information thrown away).
- A confidently wrong message also damages trust in every later message.
- Replacement buses as a secondary use: NS could start arranging them earlier when
  P(> 60 min) is high. Mention only as a possible use; it was not analysed.

### Avoid

- A numeric cost ratio (such as 3:1). The group plan proposed one, but it was never
  used. Do not present it as a result.
- More than one predictive question. The rubric asks for one.
- Promising a precise end time. The models cannot deliver that (B5).

### Use

No figure needed.

### Sources

`moddeling/01_target/output/classes.csv` (102 classes); `docs/PROCESS.md`, decisions 2
(target) and 4 (metric); underestimation rate in `table4_test_results.csv`.

---

## B4. Data preparation and descriptive analysis

Rubric: *data preparation and descriptive analysis*, 5 points. The assignment asks
for: the main preparation steps, how data-quality issues such as missing values were
handled, and only the descriptives that matter for the predictive problem, each with
an explanation of what it shows.

### Must mention: preparation

1. **Combining.** Yearly files 2011–2025 combined into one table of 62,540 records.
2. **Cleaning: 12 rules, 62,540 → 44,248** (Appendix B, Table B1). Name the largest:
   - reported and calculated duration differ by more than 1 minute: 11,031;
   - foreign route or station: 5,078;
   - route cannot be classified reliably: 999;
   - missing, non-finite or non-positive duration: 692;
   - duration over 24 hours: 344.
3. **Cleaning principle.** A doubtful record is excluded, never corrected with an
   invented value. The raw file is never changed.
4. **Missing values (the rubric names these explicitly).** Raw shares: stations
   23.51%, routes 1.88%, cause 0.30%, end time and duration 0.18%. How each is handled:
   - no valid duration or no classifiable route → removed (target or domestic scope
     cannot be established);
   - missing stations or cause → kept; the value stays empty and an indicator feature
     (`stations_missing`, `routes_missing`, `cause_missing`) marks it;
   - missing cause group → "unknown";
   - numeric gaps → training-set median.
   No rows dropped just for having an empty field.
5. **Features** (all derived from the same table, no merges):
   - from `start_time` (local Amsterdam time): hour, weekday, month, weekend, rush hour
     (weekdays 07–09 and 16–19);
   - from routes and stations: number of routes, number of stations, 5 hub flags
     (Amsterdam C., Utrecht C., Rotterdam C., Schiphol Airport, Den Haag C.), the 20 most
     frequent routes;
   - cause group, one-hot.
6. **Target.** Duration assigned to one of 102 ten-minute classes.
7. **Leakage prevention.**
   - End time, duration and statistical cause are never predictors.
   - Chronological split: training 2011–2023 (33,004), validation 2024 (5,296),
     test 2025 (5,948).
   - All preprocessing (medians, scaling, top-20 routes, categories) learned on
     training data only.
8. **Two information scenarios**, because cause and routes may be revised after the
   start: *time-only* (45 features, certainly known at the first message) and
   *archived context* (74 features, adds cause, routes, stations).

### Must mention: descriptives (each with one sentence on what it shows)

1. **Duration distribution (Figure 1).** Median 51 min; 45.1% over 60 min; 7.0% 300 min
   or longer; 1.02% in the final class (≥ 1,010 min). *Shows:* strongly right-skewed, so
   exact prediction is hard and the long tail matters most.
2. **Cause groups (Table 1).** *Shows:* cause separates short from long disruptions
   better than anything else. This foreshadows the main finding in B5.

   | Cause group | Share | Median (min) | Over 60 min |
   |---|---:|---:|---:|
   | Rolling stock | 41.7% | 27 | 23% |
   | Infrastructure | 25.0% | 111 | 71% |
   | External | 11.8% | 33 | 26% |
   | Accidents | 10.3% | 129 | 68% |
   | Engineering work | 3.7% | 106 | 68% |
   | Logistical | 3.3% | 116 | 70% |
   | Unknown | 2.1% | 53 | 39% |
   | Staff | 1.2% | 481 | 94% |
   | Weather | 1.0% | 166 | 82% |

### If there is room

- **Figure 2 (records kept and median duration per year).** Shows the 2017 break and
  explains why the survival model was also trained on 2017–2023 only. Otherwise put it
  in the appendix and keep one sentence.
- Why no outlier filter (IQR): it would remove exactly the long disruptions we want to
  predict.
- Why mixed domestic/international records are excluded completely: a conservative
  scope choice, not proof the disruption crossed the border.
- Daylight-saving: non-existent or ambiguous local times are set aside (part of the 98
  time-related removals).
- The share of unknown causes per year (link to limitation 4 in B2).

### Avoid

- Plots of variables the models do not use, or descriptives that do not relate to the
  prediction. The rubric says "only what is important".
- Saying missing values were "filled in" for stations or causes. They were not; they get
  an indicator.
- Mixing up the 12 removal counts: each row is counted once, at the first rule it hits.

### Use

Figure 1 `fig1_duration_distribution.png` · Table 1 from `table2_cause_groups.csv` ·
Figure 2 `fig2_yearly_shift.png` (main text or appendix) · Appendix B, Table B1.

### Sources

`Data Cleaning/output/cleaning_report.md` and `filter_audit.csv`;
`descriptive data analysis/raw_analysis_output/variable_dictionary.csv` (missing %);
`moddeling/16_report_inputs/output/table1_feature_dictionary.csv` (features);
`moddeling/02_voorbereiding/output/feature_sets.csv` (45/74) and `split_counts.csv`;
Figure 1 subtitle (median and shares); `table2_cause_groups.csv`.

---

## B5. Predictive modelling and performance

Rubric: *predictive modelling, performance evaluation and model selection*, 8 points:
the largest item. The assignment asks for: at least three models, an appropriate
training and evaluation strategy, justified model choices and performance measures, a
comparison, important prediction errors, and a preferred model with the reason.

### Must mention: models (at least three, each with one line on why)

| Model | Why it is included |
|---|---|
| Frequency baselines: global (time-only), per cause group (context) | The benchmark every model must beat |
| Multinomial logistic regression (ridge) | Interpretable linear model |
| Random forest (probability forest) | Non-linear effects and interactions (cause × time of day), little tuning |
| Multiclass XGBoost | Gradient boosting, usually strong on tabular data |
| Discrete-time survival boosting | Uses the order of the classes: per interval, the chance it ends there given it is still going; multiplied into the full distribution |

All models: identical records, same preprocessing, both information scenarios.

### Must mention: training and evaluation strategy

1. Tuning with small fixed grids on forward folds: train ≤ 2021 → predict 2022;
   train ≤ 2022 → predict 2023.
2. Model comparison on validation 2024.
3. Chosen models frozen, then tested **once** on 2025. Test predictions saved before
   the outcomes were loaded.
4. Survival also trained on 2017–2023 only (sensitivity to the 2017 break).

### Must mention: performance measures (and why)

- **Primary: multiclass log loss**, fixed in advance. Scores the whole distribution and
  punishes confident mistakes.
- **Intuitive reading:** exp(−log loss) = the average probability the model gives to
  what actually happened. Random guessing over 102 classes: 0.98%.
- **Secondary:** exact-class accuracy, within one class, ranked probability score (RPS,
  how many classes off).
- **Stakeholder view:** Brier score and AUC for "ends within 30 / 60 / 120 minutes".

### Must mention: validation results 2024 (full table already in Appendix C, Table C1)

- Time-only: survival 2017–2023 best (log loss 3.1905, 0.0403 better than baseline).
  Then survival 2011–2023 (0.0374), forest (0.0170), logistic (0.0136), XGBoost (0.0114).
- Context: random forest best (3.0591, 0.0125 better than the cause baseline).
- Logistic regression and XGBoost are **worse** than the simple cause baseline in the
  context scenario.
- Logistic regression has the highest exact accuracy (12.76%), but log loss was the
  selection rule fixed in advance.

### Must mention: final test 2025 (Table 2 in the main text)

| Model | Log loss | Avg. prob. on true class | Gain vs baseline (95% CI) | Exact class |
|---|---:|---:|---|---:|
| Time-only: frequency baseline | 3.2065 | 4.05% | – | 10.15% |
| Time-only: survival (2017–2023) | 3.1620 | 4.23% | 0.0445 (0.0246 to 0.0663) | 10.93% |
| Context: cause-group baseline | 3.0273 | 4.84% | – | 11.79% |
| Context: random forest | 3.0189 | 4.89% | 0.0083 (0.0012 to 0.0151) | 12.02% |

- 5,948 test disruptions. Both models beat their baseline; both intervals exclude zero
  (calendar-day bootstrap, 500 resamples).
- The forest's gain over the cause table is small.

### Must mention: main insight (Figure 3)

Information matters more than the algorithm. For "ends within 60 minutes":

| Model | Brier (lower better) | AUC (higher better) |
|---|---:|---:|
| Time-only survival | 0.2392 | 0.572 |
| Cause baseline | 0.1844 | 0.760 |
| Context random forest | 0.1852 | 0.777 |

Adding the cause lifts AUC from 0.57 to 0.76–0.78 and cuts the Brier score by about
23%. The forest adds a little ranking (AUC +0.017) but no better Brier score.

### Must mention: important prediction errors

1. **Underestimation:** the most likely class is too short in 84% (forest) to 88%
   (survival) of test cases.
2. **No precise end time:** exact class right in 11–12%, within one class in 22–26%.
3. **Wide ranges:** 80% intervals contain the outcome in about 91% of cases but are 223
   (forest) to 236 (survival) minutes wide on average.
4. **By cause (forest, test):** worst for engineering work (log loss 3.92),
   infrastructure (3.77), accidents (3.56); best for rolling stock (2.54). Appendix E.
5. **Threshold matters:** at 60 and 120 minutes the forest's Brier score is slightly
   worse than the cause table (0.1852 vs 0.1844; 0.1405 vs 0.1398).

### Must mention: preferred model and why

**Random forest with archived context.**

1. Lowest validation log loss of all 12 model–scenario combinations: the rule fixed
   before seeing the test data.
2. On the untouched 2025 test it beats the cause baseline, has the best RPS and the
   best AUC at 30, 60 and 120 minutes, and is well calibrated (predicted 56.5% vs
   observed 56.7% ending within 60 minutes).
3. **Condition:** the cause must be known at the first message. Pilot: 40 of 40 first
   messages contained a cause; it matched the final cause in substance in 37.
4. **Fallback:** time-only survival when no cause is known. Calibrated and beats its
   baseline, but barely separates short from long (AUC 0.57), so not suitable for
   individual advice.

### If there is room

- **Feature importance** (validation 2024, forest, permutation, 3 repeats on 2,000
  rows): shuffling the cause raises log loss by 0.265; route/station context by 0.022;
  time of week by 0.021; month by about 0. Supports the main insight. Association,
  not causation.
- **Why the two chosen models are not compared to each other:** they use different
  information, so their difference is not an algorithm comparison.
- **Regression experiment (not adopted):** predicting minutes directly. On 2024, context
  boosting gets MAE 68.06 min vs 78.77 for the median baseline, but gives no
  probabilities or intervals.
- **Historical features (not adopted):** network-wide counts of recent disruptions
  (24 hours, 7 days), and for context also recent disruptions on the same route or in
  the same cause group, with their median duration. Tested on the regression model:
  no MAE gain (context 68.06 → 68.95 min).
- **Survival intuition:** "given that it is still going after 40 minutes, what is the
  chance it ends in the next 10?"
- **Calibration figure** (`fig6_calibration_60min.png`) in Appendix D.

### Avoid

- Calling 2024 a test result. 2024 was used repeatedly; only 2025 is independent.
- Saying the forest is "much better". The gain over the cause table is 0.0083.
- Choosing logistic regression because it has the highest accuracy. The rule was
  log loss.
- "Within one class" as "at most 10 minutes off". The final class is open.
- Mixing the interval widths: 213.78 min is context survival on 2024, 222.88 min is
  the context forest on 2025.
- Any statement that a feature *causes* longer disruptions.

### Use

Table 2 (`table4_test_results.csv`) · Figure 3 `fig5_information_vs_algorithm.png` ·
Appendix C (Table C1, Figure C1 = `fig3_validation_comparison.png`) · Appendix D
(Table D1, Figure D1 = `fig4_test_gain_over_baseline.png`) · Appendix E.

### Sources

`moddeling/16_report_inputs/output/table3_validation_models.csv` (validation);
`table4_test_results.csv` (test, intervals, coverage, widths, underestimation);
`table5_test_decision_level.csv` (Brier, AUC, predicted and observed rates);
`moddeling/09_modelkeuze_en_test/output/test_groups.csv` (per cause);
`moddeling/09_modelkeuze_en_test/output/FINAL_TEST_REPORT.md` (500 resamples);
`moddeling/09_modelkeuze_en_test/output/B5_FINAL_REPORT_TEXT.md` (predictions saved
before labels); `moddeling/08_foutanalyse/output/permutation_summary.csv` (importance);
`moddeling/10_regressie_experiment/README.md` and
`moddeling/11_historische_kenmerken/README.md` (experiments).

---

## Appendix A, Table A2: raw columns (to add under Table A1)

| Column | Meaning | Missing |
|---|---|---:|
| rdt_id | Record identifier | 0% |
| start_time / end_time | Recorded start and end time | 0% / 0.18% |
| duration_minutes | Recorded duration in minutes | 0.18% |
| ns_lines / rdt_lines / rdt_lines_id | Affected route(s), NS and RDT naming | 0% / 1.88% / 1.88% |
| rdt_station_names / rdt_station_codes | Affected station(s) | 23.51% |
| cause_nl / cause_en | Reported cause, Dutch and English | 0.30% |
| statistical_cause_nl / _en | Statistical cause label (not used: set afterwards) | 0.30% |
| cause_group | Broad cause category (9 groups) | 0.00% |
| source_year | Year label of the source file | 0% |

Source: `descriptive data analysis/raw_analysis_output/variable_dictionary.csv`.
