# Target definition: 10-minute duration classes

Training: 2011–2023, 33004 records. Input MD5: 6f22afc6b05fe5e65ed8bd583bc5ba68.
Selected cutoff: 1010 minutes; 102 classes, including the final >=cutoff class.
Tail: 322 records. Other classes: mean 323.58, median 34.0, minimum 4.

Selection minimises the absolute count difference between the tail and the arithmetic mean of preceding classes.
No validation or test durations were used to choose the cutoff. Freeze this definition before modelling.
Intervals include the lower bound and exclude the upper bound. The final class has no upper bound.
A smaller tail does not establish statistical insignificance or improved model performance.
Fixed-width bins remain highly imbalanced. Do not oversample validation/test data or relabel rare classes per model.
All models must output probabilities in classes.csv order. A class absent in a tuning-training fold needs an explicit shared policy.
The original clean CSV is unchanged; the target is a modelling derivation.
