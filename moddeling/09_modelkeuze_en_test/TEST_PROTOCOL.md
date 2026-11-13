# Frozen final test protocol — 13 November 2026

The user explicitly authorized freezing the current winners and evaluating 2025.
Primary selection was based on 2024 multiclass log loss, independently per feature
set. Time-only: discrete-time survival trained 2017–2023. Archived context: random
forest trained 2011–2023. The context result is retrospective, not a live model.

## Before opening labels

Use the existing fitted RDS models, with their original preprocessing reconstructed
from the exact training IDs. Do not refit using 2024; this retains an exact test of
the models compared during validation. Hash model files, data, classes, prediction
code, test code and this protocol. Reconstruct all saved 2024 predictions and check
that they match. Generate and hash all 2025 predictions before importing labels.
All eligible 2025 rows must be retained; no filtering based on test performance.

Evaluate two chosen models and two prespecified baseline comparators:

- Survival: Laplace global frequencies from 2017–2023, alpha = 1.
- Forest: cause-group baseline from 2011–2023, global alpha = 1 and shrinkage
  prior mass lambda = 102. Use the shared cause preprocessing and fallback.

The two feature sets have different information assumptions and training cohorts;
do not interpret their cross-set score difference as an isolated algorithm effect.

## Reporting fixed in advance

Primary: natural-log multiclass log loss. Secondary: exact accuracy, macro-F1,
within-one-class percentage, under/overestimation and RPS. Report support and
open-tail limitations. Evaluate probabilities of T < 30, 60, 120 using Brier scores
and fixed-width reliability bins. Report central 80% class interval coverage,
finite-width average and fraction with an infinite upper bound. No interval
recalibration using test outcomes.

Compare each selected model against its matched baseline with 500 paired
calendar-day bootstrap resamples, seed 42. Use the difference in mean log loss
(model minus baseline; negative favours model). These intervals assume observed
days are useful resampling clusters and do not capture longer temporal dependence.
Report cause-group and month errors with group support; groups below 50 are flagged.
Compare frozen validation and test metrics descriptively, without attributing
differences automatically to model drift.

## After opening labels

Keep all results, favourable or not. Do not select another model, tune settings,
change class boundaries, cleaning, threshold choices or metrics based on 2025.
Any later model development must be labelled exploratory and requires new external
holdout data for a fresh final evaluation. Reproduction of an unchanged evaluation
is different from model selection, but the default script blocks accidental reruns.

Claims remain conditional on the cleaned population, which was selected using
outcomes. Temporal holdout does not undo retrospective selection/feature bias.

## Commands

```sh
# Validate provenance, freeze hashes and reconstruct validation; labels stay locked.
Rscript moddeling/09_modelkeuze_en_test/final_test.R
# Only after authorization and successful freeze:
Rscript moddeling/09_modelkeuze_en_test/final_test.R --unlock-test
```
