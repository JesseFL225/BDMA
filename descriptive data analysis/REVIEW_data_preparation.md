# Review of the data preparation (B2 and B4)

Reviewer: Max (Analyst). Reviewed: the data engineer's work in `data/` and `Data Cleaning/`,
the feature preparation in `moddeling/02_voorbereiding/`, and Appendix A and B of the report.
Date: 19 November 2026. Checks: `descriptive data analysis/review_clean_data.R`
(numbers in `clean_analysis_output/review_checks.csv`). Prepared with AI assistance.

## Verdict

The clean file can be used as it is. It rebuilds from the raw file, every derived column
is correct, and it is the file the models were tested on. Nothing in `data/` has to change,
and nothing may change: the clean file is frozen for the 2025 test.

The points below are about how the report describes the data (1 to 6) and about small
fixes in the documentation and the cleaning script (7 to 9).

## What was checked and passed

| Check | Result |
|---|---|
| Raw file: 62,540 records, unique IDs, all 15 years, year label fits the start time | passed |
| Clean + excluded = raw, no ID in both, filter table adds up to 18,292 excluded | passed |
| Cleaning script rerun in a separate copy (R 4.3.3, Linux) | same 44,248 rows, IDs and values |
| Clean file equals the frozen file of the final test (MD5 `6f22afc6…`) | passed |
| Duration: whole minutes, 1 to 1,440, within 1 minute of end minus start | passed |
| Start hour, weekday, month and year are local Dutch time | passed |
| The script's own tests (`test_clean_disruptions.R`) | passed |
| Shared preparation checks (`validate_preparation.R`, 34 checks) | passed, output identical |
| Appendix B table against `filter_audit.csv` | identical |

Not checked: the raw file against the original yearly downloads. The source site could not
be reached from the review environment. The size of each year in the raw file is consistent
with the file sizes listed on the source page, so no year looks incomplete.

## Findings

### 1. Filter 12 removes a different definition, not random errors

Filter 12 removes 11,031 records whose reported duration differs more than one minute from
end time minus start time. All of them are from 2011 to 2016. In every one of them the
reported duration is the shorter of the two (median difference 23 minutes, middle half
14 to 36 minutes). Before 2017 the two fields were therefore defined differently; they are
not noisy copies of each other.

Consequence: only 11.7% of the 2011–2016 records are kept (1,715 of 14,694), against 88.9%
from 2017. The kept early records are not typical: their median duration is 118 minutes,
against 90 minutes for the records that filter 12 removed.

Action: describe 2011–2016 as a small, selected sample in sections 2 and 4. No new cleaning.

### 2. Filter 5 is wider than "foreign route"

Filter 5 removes 5,078 records. For 4,448 the standardised route has a foreign end point.
The other 630 were removed because a foreign name occurs in the text. Of these, 504 have a
Dutch standardised route: the disruption is in the Netherlands, but NS announced it for an
international service, for example "Amsterdam-Rotterdam-Brussel (HSL)" (143 records).

Action: word the scope as "disruptions that involve international services or foreign
stations", not "foreign routes".

### 3. Station information is missing for every disruption before 2017

`stations_missing` is TRUE for all 1,715 disruptions of 2011–2016 and FALSE for all 42,533
later ones. The feature is therefore a "before 2017" flag. Station count and the hub flags
carry no information before 2017 (the count is filled with the training median).

The route is never missing in the clean file, because the cleaning removes records without
a route. So `routes_missing` is always 0 and `route_count` is never imputed.

Action: correct these two lines in Appendix A (data dictionary).

### 4. The data dictionary misses the target

Appendix A lists the model features only. Add the target (`duration_minutes`, turned into
102 ten-minute classes), the split variable (`start_year`), and the column "known at the
first message?" that is already in `table1_feature_dictionary.csv`. That column carries the
leakage warning.

### 5. Very short records are probably withdrawn messages

The cleaning removes 691 records of zero minutes (all from 2017 on). It keeps 1,350 records
of one or two minutes (3.1% of the clean data). In addition, 30 records share their start
second and route with another record, for example IDs 24472 and 24474 (226 minutes and
1 minute). These short records fall in the first target class.

Action: name this as label noise in the limitations. No change to the data.

### 6. The stored cause is the last cause

The source documentation says that the cause column holds the last cause NS used. In 334
clean records the stored cause differs from the statistical (original) cause, mostly because
it became "an earlier disruption" (305). Their median duration is 139 minutes, against 50
for the other records, and 90% last longer than an hour, against 45%. This supports the
choice to report a time-only scenario next to the context scenario. It is in section 2 now.

The cause group "unknown" covers 4.6% of the disruptions in 2024 and 5.1% in 2025, against
1.1% in the training years.

### 7. Rerunning the cleaning can break the frozen-file check

A rerun on another machine gives the same rows and values, but 13 cells of
`difference_minutes` are printed with one digit more or less (0.0999999999999091 against
0.099999999999909). That changes the MD5 of the clean file, and `moddeling/run_all.R` then
stops with "Frozen files changed". The models do not read this column.

Action: add one line to `data/README.md` and `Data Cleaning/README.md`: rerun the cleaning
only in a separate copy; restore the file with `git checkout` if it was overwritten.

### 8. In a non-UTF-8 locale the cleaning script silently reads 60 rows

With a C/POSIX locale, `read.csv(..., fileEncoding = "UTF-8")` stops at the first accented
character, gives only a warning, and the script writes a clean file of 54 rows. The only
guard is `nrow(raw) > 0`.

Action: add `stopifnot(nrow(raw) == 62540)` after the read in `clean_disruptions.R`. The
script is not in the frozen manifest.

### 9. Two wording points for section 1

- The source page names NS as the source of the messages. It does not mention ProRail.
- The source page explains the 2017 change: NS started to announce disruptions earlier,
  which added many short ones. Section 1 can cite this for "registration practice changed".

## Outside the data engineer's work

`fig1_duration_distribution.png` (step 16) says that each bar is one target class, but
`hist()` uses bars of (0, 10], (10, 20] and so on, while the classes are [0, 10), [10, 20).
The first bar shows 6,504 disruptions; the first class holds 5,940. The x-axis title is also
cut off in the PNG. Panel A of the new Figure 1 uses the target classes (`right = FALSE`).
