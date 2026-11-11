# Step 01 — Fixed duration target

Owner: Mart. Reviewer: Oliver. Status: completed; reused by Steps 02–04 and 07.

Input: `data/disruptions_2011_2025_clean.csv`, 44,248 records. Base R only.
The cutoff was selected using only 33,004 training events from 2011–2023.
The chosen 1010-minute cutoff minimises the absolute difference between the
tail count and the mean count of preceding ten-minute intervals.

Frozen target: 102 ordered classes, IDs 0–101: [0,10), [10,20), ...,
[1000,1010), [1010,+Inf). The tail has 322 training events; preceding
classes average 323.58 events, median 34, minimum 4. Classes remain imbalanced.
This construction does not imply equal class sizes or statistical insignificance.

Required outputs in `output/`: `classes.csv`, `training_class_counts.csv`,
`selected_cutoff.csv`, `cutoff_candidates.csv`, and the method README.
All models must use classes.csv order and keep the open-ended class separate.
Do not assign an invented minute midpoint to the final class.

To reproduce target selection intentionally from the repository root:
```r
source("moddeling/01_target/define_duration_classes.R")
```

This driver regenerates Step 01 outputs. Normal modelling must instead call
Step 02 `prepare_data()`, which reuses the existing assignment function without
executing the driver or reselecting the target. The frozen class CSV and target
code were preserved during publication; boundary checks at 9, 10, 19, 20,
1009, 1010 and 1440 minutes are executed in Step 02 validation.

Next member: source Step 02 for matrices/labels and Step 07 for evaluation.
No 2025 target outcomes are needed to fit preprocessing or select models.
