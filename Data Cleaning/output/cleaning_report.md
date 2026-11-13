# Cleaning of Dutch train disruptions

Source: `data/disruptions_2011_2025_raw.csv` (MD5: `757d2c2aff9405c9ef9992b6b2476af0`).
From **62540** raw rows to **44248** selected disruptions. **18292** rows set aside.

## Steps and counts

| Step | Rule | Removed in this step | Remaining |
|---|---|---:|---:|
| 1 | Exact duplicate rows | 0 | 62540 |
| 2 | Invalid or conflicting IDs | 0 | 62540 |
| 3 | Test messages | 1 | 62539 |
| 4 | Information and follow-up messages | 49 | 62490 |
| 5 | Foreign route or station | 5078 | 57412 |
| 6 | Route cannot be classified reliably | 999 | 56413 |
| 7 | Missing/invalid/ambiguous time | 98 | 56315 |
| 8 | Missing, non-finite or non-positive duration | 692 | 55623 |
| 9 | End not after start | 0 | 55623 |
| 10 | Invalid or inconsistent source year | 0 | 55623 |
| 11 | Reported or calculated duration above 24 hours | 344 | 55279 |
| 12 | Duration difference above 1 minute | 11031 | 44248 |

A row can match several rules. The table counts each row once, at the first rule it matches. `excluded_disruptions.csv` keeps the original values, CSV row number, first reason, all reasons and any foreign names found.

## Choices and limitations

- This is a strict, reproducible analysis selection, not proof that every excluded record is wrong. The raw data are preserved; the clean CSV in data/ is rebuilt.
- Maximum duration: 1440 minutes. Both the reported and the calculated duration must be within the limit. Long bridge damage, strikes and weather problems can be genuine incidents. This selection only predicts within the selected duration population; at onset you do not yet know whether a disruption will last longer than 24 hours. For deployment, also evaluate on all valid durations.
- A duration difference above 1 minute leads to exclusion, not to an invented correction. This mainly removes early years and changes the population. See `yearly_retention.csv`, `yearly_profile.csv` and `threshold_sensitivity.csv`.
- Domestic means: all standardised route endpoints are on the explicit Dutch list, and no foreign name is found in the location fields. A mixed domestic/international record is excluded entirely. This is a deliberate, conservative scope; it does not prove that the actual disruption was across the border.
- Missing or unknown standardised routes are set aside: the free NS text is not reliable enough to guarantee domestic endpoints automatically. Unknown future endpoints are never automatically treated as Dutch.
- Test messages are recognised explicitly. Journey-planner problems, information messages and explanations are set aside, because they could otherwise be counted twice next to an original disruption. The exact patterns are in the script. Unrecognisable test messages cannot be guaranteed to be detected without further source information.
- Missing station and cause data remain NA, with indicators. No stations or causes are invented. Only a missing cause_group becomes unknown. Removing all rows with NA would needlessly discard historical data.
- Local source times are interpreted as Europe/Amsterdam. Non-existent and ambiguous daylight-saving moments are set aside for checking. Output timestamps are in UTC; month, weekday (Monday=1) and hour remain local.
- `long_disruption` (duration_minutes > 60) is a helper column from the original binary plan; the final modelling target is 102 duration classes (see moddeling/01_target and docs/PROCESS.md, decision 2). The original statistical cause is kept for inspection but must not be a model predictor. End time and all duration fields are not predictors either. The last recorded cause may also contain information from after the start.
- No automatic removal of genuine disruption groups such as engineering work, strikes or unknown causes. No IQR filter: that would remove exactly the long disruptions in the class we want to predict.

## Run

```sh
Rscript "Data Cleaning/clean_disruptions.R"
```

Only base R is needed. Limits and lists are at the top of / in the script. The script checks totals, IDs, filters, target and the saved CSV. Outputs and data/disruptions_2011_2025_clean.csv are replaced when re-run; the raw source is not.

Source definitions and limitations: https://www.rijdendetreinen.nl/open-data/treinstoringen
Dataset attribution: Rijden de Treinen, CC BY 4.0. Cleaning script prepared with AI assistance.
