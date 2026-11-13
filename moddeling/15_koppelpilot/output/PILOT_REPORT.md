# Pilot results — first NS/NDOV messages

Run on 13 November 2026. Feasibility study, not a model result.

| Pilot day | Clean disruptions | Uniquely linked (provisional) | Ambiguous | No candidate | Initial-message evidence | Forecast time present |
|---|---:|---:|---:|---:|---:|---:|
| 2017-11-10 | 7 | 7 | 0 | 0 | 7 | 2 |
| 2020-11-10 | 18 | 17 | 0 | 1 | 15 | 4 |
| 2023-11-10 | 17 | 16 | 1 | 0 | 16 | 16 |

Total: 40/42 provisionally linked one-to-one (95.2%). This is the linkage yield on three chosen days, not a proven match precision or a national coverage estimate.
38/40 linked messages have sequence number 1 and an initial phase. A numeric forecast time is present in 22/40; its meaning/code must be kept.
In 5/40 the first cause differs from the final cause in the existing CSV. Compared after normalising case, whitespace and a leading ‘door’/‘een’; other synonyms are not merged. The cause was not used to choose the link.

## Time and availability

Median difference between safe message availability and the RDT start: 1.000 seconds; minimum 0.000, maximum 34.544.
9/40 first messages were available at or before the exact RDT start on this strict clock.
A positive delay is not hidden. For follow-up work, predicting at receipt of the first message fits better than claims about the exact physical incident start. This changes the operational prediction moment and must be recorded explicitly.

## Source quality and interpretation

12/12 downloads succeeded. Total 172,148 compressed bytes. Files are stored locally and verified with SHA-256.
Forecast codes in linked first messages: {'2': 2, '6': 2, '1': 16, '4': 20}.
PIL was used for linkage; VTBL was only inventoried. No later updates were added to first messages. The final location is still used for linkage: a remaining retrospective selection limitation.
A one-day lookback and sequence/phase help detect incomplete start histories, but do not prove archive completeness. Unique time/location candidates are not manually confirmed ground truth.
All three days are in November; results must not be extrapolated to all seasons/years. Cause, end time and model scores are not linkage criteria.

## Conclusion and next step

The pilot shows whether original operational information can be retrieved technically. There is no evidence yet of better predictive quality.
First extend the linkage validation to a pre-chosen, season-spread sample, review ambiguous and unlinked cases, and fix the prediction moment. Only then build an enriched research dataset.
Use the first NS recovery forecast as a separate baseline where semantically appropriate. Compare models with and without the forecast on the same rows. A lower bound or unknown forecast must not be scored as an exact point estimate.
The original clean CSV, models and frozen test files are unchanged. 2025 remains an already-viewed final test; new training requires a new evaluation plan.

## Checks

See checks.csv, independent_checks.csv and test_pilot.py. The re-check rebuilds every exported feature directly from the original XML line. Code and report were prepared with AI assistance.
