# B5 — Predictive modelling, performance and selection

We predicted a distribution over 102 ordered duration classes: ten-minute
intervals up to 1,010 minutes and an open final class. We compared global and
cause-group frequency baselines, multinomial ridge logistic regression, probability
random forest, multiclass XGBoost and discrete-time survival boosting. All models
used common preprocessing and identical validation records. We separated time-only
features from archived context, because final causes and affected routes may have
been revised after onset.

Settings were selected using chronological forward folds ending in 2022 and 2023.
The 2024 validation set informed development and model selection. Multiclass log
loss was the primary metric; accuracy, macro-F1, ordinal error and ranked probability
score were secondary diagnostics. Regression and historical-feature experiments
were supplementary: historical features did not improve regression MAE with fixed
settings. A recent-period sensitivity analysis refitted survival on 2017–2023.

Discrete-time survival estimates the probability of an incident ending in each
interval conditional on reaching that interval. Multiplying the conditional
survival probabilities produces the same 102-class output. Person-period rows
remain within their original chronological split. A finite-interval event contributes
one positive ending indicator; the final open class contributes remaining survival
mass. Training-only marginal hazards provide baseline offsets. This approach shares
structure across durations and supplies coherent recovery probabilities.

## Validation and model choice

| Model | Time-only log loss | Archived-context log loss |
|---|---:|---:|
| Global / cause baseline respectively | 3.2309 | 3.0716 |
| Multinomial logistic regression | 3.2173 | 3.0820 |
| Random forest | 3.2139 | **3.0591** |
| Multiclass XGBoost | 3.2195 | 3.0844 |
| Survival, all training years | 3.1935 | 3.0678 |
| Survival, 2017 onward | **3.1905** | 3.0627 |

We froze recent-period survival for time-only prediction and forest for archived
context before opening 2025. Forest's validation advantage over recent-period
context survival was small and uncertain. Logistic regression had the highest
context exact-class accuracy (12.76%), illustrating why selection depends on the
prespecified metric. The two chosen models represent different information scenarios;
we do not interpret their difference as a controlled comparison of algorithms.

## Final test

We retained the original fitted models without refitting on 2024. All 5,948 eligible
2025 incidents were evaluated. Predictions were saved before test labels were
imported; source, model and data hashes were fixed and checked. Each comparator
baseline used the selected model's own training period and information set.

| Frozen model / matched baseline | Test log loss | Exact accuracy | RPS |
|---|---:|---:|---:|
| Time-only survival, 2017–2023 | **3.1620** | **10.93%** | **0.05908** |
| Global frequency, 2017–2023 | 3.2065 | 10.15% | 0.06422 |
| Archived-context forest, 2011–2023 | **3.0189** | **12.02%** | **0.05048** |
| Cause-group baseline, 2011–2023 | 3.0273 | 11.79% | 0.05178 |

The paired calendar-day bootstrap interval for model-minus-baseline log loss was
−0.0663 to −0.0246 for survival (difference −0.0445) and −0.0151 to −0.0012 for
forest (difference −0.0083). These intervals use 500 observed-day resamples and do
not capture all longer temporal dependence. Forest's gain over cause frequencies
is small, not a large practical improvement. We did not use these results to
retune or replace models.

## Errors, uncertainty and implications

Only 22.23% of time-only and 26.03% of context predictions were within one class
of the outcome. Modal predictions underestimated class in 87.88% and 83.84% of
cases respectively; rare long-duration classes remain difficult. Class distance
is not a minute-level error, particularly for the open final class.

The context forest's central 80% class intervals covered 90.97% of test outcomes;
98.39% had finite upper bounds, with mean finite width 222.88 minutes. Coarse
boundary bins can raise coverage above nominal, and broad intervals are not
precise passenger promises. These are model-based, not guaranteed intervals.
The context forest's Brier scores at 60 and 120 minutes were slightly worse than
the cause baseline despite its better overall log loss. Probability quality must
therefore be checked for the stakeholder's particular decision threshold.

The study demonstrates modest predictive value beyond simple frequencies, but
does not achieve reliable exact ten-minute end-time predictions. Operational use
would require onset-available context and an evaluation covering all eligible new
incidents. Outcome-based cleaning excludes durations over 24 hours and changes
the population; an untouched temporal test does not remove that selection bias.
Later model development requires new holdout data for a fresh final claim.

Sources for the survival formulation and implementation are in Step 13's README.
AI assistance was used; the group remains responsible for explaining the analysis.
This section is draft report material, to be integrated within the five-page limit.
