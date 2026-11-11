# Raw train disruption data: descriptive analysis

Input: `./disruptions_2011_2025_raw.csv`. Contains 62,540 records and 15 variables. No raw records were removed.

## Main findings

- The median recorded duration is 61 minutes, compared with a mean of 160.04 minutes (including zero durations, excluding missing values). The higher mean indicates a right-skewed distribution.
- The longest recorded duration is 64,927 minutes (45.1 days), so extreme records warrant review.
- rolling stock is the most frequent cause group: 23,062 records (36.88%).
- Among cause groups with positive durations, staff has the longest median duration (554 minutes).
- Annual recorded counts range from 1,846 to 6,676. These counts are not adjusted for service volumes or changes in reporting.
- Inspect the annual coverage table before year-to-year comparisons; an early last observation can indicate a coverage gap.
- 827 durations are zero and 111 are missing. 12,158 recorded durations differ from the naive timestamp interval by more than one minute; investigate the source definition before recalculating durations.

## Variable meanings and completeness

Definitions are inferred from column names and observed values; an official codebook was not supplied. Missingness treats empty CSV cells and literal NA as missing. Route and station fields may contain multiple values.

| variable | imported_type | meaning | nonmissing | missing | missing_pct | distinct_nonmissing |
| --- | --- | --- | --- | --- | --- | --- |
| rdt_id | integer | Record identifier; uniqueness is checked below. | 62540 | 0 | 0 | 62540 |
| ns_lines | character | Affected railway route(s), using the NS naming field. | 62540 | 0 | 0 | 3371 |
| rdt_lines | character | Affected railway route(s), using the RDT naming field. | 61365 | 1175 | 1.88 | 686 |
| rdt_lines_id | character | Route identifier(s); stored as text because a cell may contain multiple IDs. | 61365 | 1175 | 1.88 | 686 |
| rdt_station_names | character | Affected station name(s), where recorded. | 47838 | 14702 | 23.51 | 2111 |
| rdt_station_codes | character | Affected station code(s), where recorded. | 47838 | 14702 | 23.51 | 2111 |
| cause_nl | character | Reported disruption cause in Dutch. | 62355 | 185 | 0.3 | 102 |
| cause_en | character | Reported disruption cause in English. | 62355 | 185 | 0.3 | 98 |
| statistical_cause_nl | character | Statistical cause label in Dutch; exact coding rules are unverified. | 62355 | 185 | 0.3 | 102 |
| statistical_cause_en | character | Statistical cause label in English; exact coding rules are unverified. | 62355 | 185 | 0.3 | 98 |
| cause_group | character | Broad category grouping disruption causes. | 62538 | 2 | 0 | 9 |
| start_time | character | Recorded start timestamp; source timezone is unspecified. | 62540 | 0 | 0 | 62458 |
| end_time | character | Recorded end timestamp; source timezone is unspecified. | 62430 | 110 | 0.18 | 61816 |
| duration_minutes | integer | Recorded disruption duration in minutes. | 62429 | 111 | 0.18 | 1792 |
| source_year | integer | Year label of the source data; compared with the start timestamp below. | 62540 | 0 | 0 | 15 |

## Data quality

| check | count |
| --- | --- |
| Rows | 62540 |
| Columns | 15 |
| Exact duplicate rows (after first occurrence) | 0 |
| Repeated nonmissing record IDs (after first occurrence) | 0 |
| Missing durations | 111 |
| Zero durations | 827 |
| Negative durations | 0 |
| Nonfinite nonmissing durations | 0 |
| Nonmissing start timestamps that fail parsing | 0 |
| Nonmissing end timestamps that fail parsing | 0 |
| End before start | 0 |
| Source year differs from start year | 0 |
| Duration differs from timestamp interval by more than 1 minute | 12158 |
| Positive durations over 24 hours | 548 |
| Positive durations over 7 days | 46 |

Zero and negative durations are quality flags, not automatically errors to delete. Extremely long events also require investigation before exclusion. Timestamp comparisons use naive clock differences because the original timezone is unspecified.

## Duration distribution

| measure | minutes_or_count |
| --- | --- |
| Nonmissing finite observations | 62429 |
| Minimum | 0 |
| 25th percentile | 22 |
| Median | 61 |
| Mean | 160.04 |
| 75th percentile | 146 |
| 90th percentile | 280 |
| 95th percentile | 490.6 |
| Maximum | 64927 |
| Standard deviation | 792.44 |

This distribution includes all recorded finite durations. The group tables below calculate duration statistics only for positive finite durations. Compare median and mean to assess skew; inspect the longest records before interpreting extremes.

## Annual patterns

| group | records | pct_of_all_records | valid_duration_n | median_minutes | mean_minutes | total_recorded_minutes | pct_over_120_minutes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2011 | 1846 | 2.95 | 1846 | 116 | 170.17 | 314128 | 47.72 |
| 2012 | 2074 | 3.32 | 2074 | 98 | 237.55 | 492678 | 41.32 |
| 2013 | 2312 | 3.7 | 2312 | 95 | 175.11 | 404863 | 40.53 |
| 2014 | 2484 | 3.97 | 2484 | 99 | 179.32 | 445435 | 41.55 |
| 2015 | 2947 | 4.71 | 2947 | 86 | 150.73 | 444204 | 37.84 |
| 2016 | 3031 | 4.85 | 3031 | 82 | 155.09 | 470080 | 36.23 |
| 2017 | 4085 | 6.53 | 4043 | 73 | 125.25 | 506381 | 34.23 |
| 2018 | 5190 | 8.3 | 5088 | 59 | 129.51 | 658931 | 27.87 |
| 2019 | 5940 | 9.5 | 5564 | 45 | 103.44 | 575551 | 24.55 |
| 2020 | 4450 | 7.12 | 4271 | 44 | 136.32 | 582222 | 25.19 |
| 2021 | 4874 | 7.79 | 4859 | 46 | 149.18 | 724880 | 26.08 |
| 2022 | 5499 | 8.79 | 5438 | 46 | 185.65 | 1009568 | 28.52 |
| 2023 | 5168 | 8.26 | 5130 | 57 | 260.18 | 1334713 | 32.5 |
| 2024 | 5964 | 9.54 | 5909 | 52 | 154.15 | 910867 | 28.11 |
| 2025 | 6676 | 10.67 | 6606 | 52 | 169.02 | 1116575 | 27.87 |

### Observed annual coverage

| source_year | first_recorded_start | last_recorded_start |
| --- | --- | --- |
| 2011 | 2011-01-03 23:22:50 | 2011-12-31 05:52:01 |
| 2012 | 2012-01-01 02:20:01 | 2012-12-31 04:10:01 |
| 2013 | 2013-01-01 07:39:01 | 2013-12-31 16:36:01 |
| 2014 | 2014-01-01 12:57:02 | 2014-12-31 13:44:02 |
| 2015 | 2015-01-01 09:33:01 | 2015-12-31 18:17:02 |
| 2016 | 2016-01-01 11:59:01 | 2016-12-31 16:50:01 |
| 2017 | 2017-01-01 07:28:38 | 2017-12-31 15:12:25 |
| 2018 | 2018-01-01 06:19:43 | 2018-12-31 13:04:24 |
| 2019 | 2019-01-01 06:32:16 | 2019-12-31 18:59:39 |
| 2020 | 2020-01-01 07:42:15 | 2020-12-31 20:15:56 |
| 2021 | 2021-01-01 08:12:55 | 2021-12-31 15:54:31 |
| 2022 | 2022-01-01 05:45:33 | 2022-12-31 18:19:03 |
| 2023 | 2023-01-01 08:19:26 | 2023-12-21 11:15:15 |
| 2024 | 2024-01-01 07:03:51 | 2024-12-31 16:09:32 |
| 2025 | 2025-01-01 04:16:38 | 2025-12-31 19:41:03 |

First and last timestamps indicate the observed range, not verified collection completeness. Differences in collection, coding and service volumes may affect comparisons across years.

## Broad cause categories

| group | records | pct_of_all_records | valid_duration_n | median_minutes | mean_minutes | total_recorded_minutes | pct_over_120_minutes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| rolling stock | 23062 | 36.88 | 22611 | 30 | 82.32 | 1861239 | 11.88 |
| infrastructure | 17103 | 27.35 | 16883 | 107 | 180.07 | 3040167 | 43.84 |
| external | 6831 | 10.92 | 6734 | 35 | 72.26 | 486576 | 12.27 |
| accidents | 6633 | 10.61 | 6563 | 133 | 144.06 | 945451 | 54.17 |
| engineering work | 2865 | 4.58 | 2831 | 118 | 349.53 | 989507 | 48.99 |
| logistical | 2538 | 4.06 | 2509 | 122 | 274.69 | 689193 | 50.38 |
| unknown | 1468 | 2.35 | 1458 | 62 | 161.74 | 235813 | 26.34 |
| staff | 1192 | 1.91 | 1177 | 554 | 1078.06 | 1268879 | 92.27 |
| weather | 846 | 1.35 | 834 | 179 | 568.55 | 474172 | 67.27 |
| (Missing) | 2 | 0 | 2 | 39.5 | 39.5 | 79 | 0 |

## Most frequent reported causes (top 15)

| group | records | pct_of_all_records | valid_duration_n | median_minutes | mean_minutes | total_recorded_minutes | pct_over_120_minutes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| broken down train | 19121 | 30.57 | 18758 | 28 | 46.43 | 871005 | 8.05 |
| signal failure | 4946 | 7.91 | 4879 | 110 | 151.76 | 740434 | 44.6 |
| points failure | 4263 | 6.82 | 4198 | 102 | 142.27 | 597268 | 40.26 |
| collision | 3447 | 5.51 | 3406 | 106 | 123.51 | 420687 | 46.8 |
| stranded train | 2735 | 4.37 | 2659 | 28 | 51.22 | 136185 | 9.1 |
| person hit by a train | 2315 | 3.7 | 2295 | 158 | 163.82 | 375975 | 74.34 |
| an emergency call | 2092 | 3.35 | 2065 | 27 | 47.08 | 97228 | 8.18 |
| repair works | 1655 | 2.65 | 1631 | 124 | 387.81 | 632518 | 51.26 |
| damaged overhead wires | 1447 | 2.31 | 1420 | 184.5 | 336 | 477123 | 62.75 |
| person on the railway track | 1399 | 2.24 | 1376 | 28 | 33.32 | 45846 | 1.38 |
| damaged railway bridge | 1381 | 2.21 | 1366 | 80 | 153.05 | 209071 | 23.65 |
| signalling and points failure | 1108 | 1.77 | 1101 | 100 | 152.59 | 168006 | 41.96 |
| an earlier disruption | 1053 | 1.68 | 1049 | 111 | 166.96 | 175142 | 46.81 |
| level crossing failure | 1018 | 1.63 | 1005 | 87 | 121.4 | 122008 | 33.73 |
| power failure | 969 | 1.55 | 963 | 97 | 131.79 | 126916 | 40.19 |

## Most frequent route field values (top 10)

| group | records | pct_of_all_records | valid_duration_n | median_minutes | mean_minutes | total_recorded_minutes | pct_over_120_minutes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Breda - Rotterdam Centraal (HSL) | 1971 | 3.15 | 1959 | 41 | 102.4 | 200610 | 19.4 |
| (Missing) | 1175 | 1.88 | 1175 | 122 | 459.75 | 540207 | 50.47 |
| 's-Hertogenbosch - Nijmegen | 1172 | 1.87 | 1152 | 42 | 92.21 | 106226 | 22.22 |
| Amersfoort - Zwolle | 1073 | 1.72 | 1065 | 58 | 125.72 | 133897 | 29.3 |
| Eindhoven - Venlo | 1012 | 1.62 | 1004 | 51 | 103.9 | 104311 | 27.19 |
| Amsterdam Centraal - Schiphol Airport, Rotterdam Centraal - Schiphol Airport (HSL) | 1009 | 1.61 | 972 | 58 | 127.85 | 124270 | 27.06 |
| Den Haag HS - Rotterdam Centraal | 987 | 1.58 | 961 | 52 | 116.33 | 111789 | 26.74 |
| Leiden Centraal - Schiphol Airport | 979 | 1.57 | 967 | 34 | 119.95 | 115990 | 24.41 |
| Breda - Tilburg | 971 | 1.55 | 964 | 44 | 93.48 | 90115 | 25.41 |
| Dordrecht - Rotterdam Centraal | 916 | 1.46 | 893 | 52 | 196.79 | 175734 | 24.19 |

Each route value is counted as recorded, including combinations. Counts cannot establish line reliability without the number of services operated.

## Month of start (pooled across years)

| group | records | pct_of_all_records | valid_duration_n | median_minutes | mean_minutes | total_recorded_minutes | pct_over_120_minutes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | 5503 | 8.8 | 5426 | 69 | 184.68 | 1002093 | 33.19 |
| 02 | 4992 | 7.98 | 4945 | 66 | 208.45 | 1030789 | 31.91 |
| 03 | 4809 | 7.69 | 4746 | 67 | 198.79 | 943461 | 33.23 |
| 04 | 4602 | 7.36 | 4479 | 60 | 162.95 | 729870 | 28.62 |
| 05 | 5020 | 8.03 | 4963 | 62 | 137.63 | 683070 | 31.05 |
| 06 | 5494 | 8.78 | 5425 | 65 | 168.1 | 911923 | 33.42 |
| 07 | 5389 | 8.62 | 5310 | 64 | 147 | 780572 | 31.26 |
| 08 | 5175 | 8.27 | 5059 | 61 | 141.77 | 717196 | 30.9 |
| 09 | 5176 | 8.28 | 5105 | 58 | 139.62 | 712771 | 29.29 |
| 10 | 5394 | 8.62 | 5335 | 55 | 133.24 | 710811 | 28.36 |
| 11 | 5688 | 9.09 | 5613 | 60 | 144.79 | 812701 | 31.07 |
| 12 | 5298 | 8.47 | 5196 | 61 | 183.95 | 955819 | 30.48 |

## Weekday of start (pooled across years)

| group | records | pct_of_all_records | valid_duration_n | median_minutes | mean_minutes | total_recorded_minutes | pct_over_120_minutes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 Monday | 10483 | 16.76 | 10315 | 63 | 167.44 | 1727099 | 31.29 |
| 2 Tuesday | 10247 | 16.38 | 10086 | 63 | 165.03 | 1664475 | 30.06 |
| 3 Wednesday | 9791 | 15.66 | 9636 | 62 | 163.32 | 1573766 | 31.16 |
| 4 Thursday | 10045 | 16.06 | 9899 | 62 | 145.83 | 1443581 | 30.33 |
| 5 Friday | 9414 | 15.05 | 9282 | 62 | 179.03 | 1661747 | 31.53 |
| 6 Saturday | 6480 | 10.36 | 6400 | 64 | 166.71 | 1066937 | 33.03 |
| 7 Sunday | 6080 | 9.72 | 5984 | 58 | 142.63 | 853471 | 30.83 |

## Hour of start (pooled across years)

| group | records | pct_of_all_records | valid_duration_n | median_minutes | mean_minutes | total_recorded_minutes | pct_over_120_minutes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 00 | 557 | 0.89 | 551 | 52 | 189.93 | 104654 | 27.04 |
| 01 | 213 | 0.34 | 209 | 203 | 398.61 | 83310 | 66.51 |
| 02 | 202 | 0.32 | 193 | 783 | 1047.11 | 202092 | 78.76 |
| 03 | 294 | 0.47 | 291 | 539 | 1145.82 | 333434 | 84.54 |
| 04 | 771 | 1.23 | 765 | 362 | 821.54 | 628480 | 77.12 |
| 05 | 2068 | 3.31 | 2032 | 141 | 382.68 | 777600 | 55.31 |
| 06 | 3123 | 4.99 | 3085 | 83 | 178.16 | 549633 | 39.58 |
| 07 | 3916 | 6.26 | 3863 | 69 | 183.67 | 709526 | 33.13 |
| 08 | 3866 | 6.18 | 3827 | 64 | 152.08 | 581995 | 30.65 |
| 09 | 3614 | 5.78 | 3563 | 60 | 144.26 | 514008 | 29.08 |
| 10 | 3547 | 5.67 | 3504 | 59 | 159.16 | 557696 | 29.31 |
| 11 | 3534 | 5.65 | 3486 | 58 | 133.86 | 466642 | 28.74 |
| 12 | 3414 | 5.46 | 3366 | 64 | 154.13 | 518809 | 29.8 |
| 13 | 3403 | 5.44 | 3348 | 60 | 133.35 | 446450 | 30.44 |
| 14 | 3422 | 5.47 | 3381 | 64 | 124.29 | 420223 | 30.79 |
| 15 | 3800 | 6.08 | 3737 | 62 | 130.12 | 486277 | 30.69 |
| 16 | 3865 | 6.18 | 3815 | 58 | 155.43 | 592970 | 29.62 |
| 17 | 3863 | 6.18 | 3771 | 52 | 113.68 | 428701 | 26.33 |
| 18 | 3518 | 5.63 | 3462 | 50 | 107.9 | 373558 | 24.73 |
| 19 | 3170 | 5.07 | 3116 | 52.5 | 103.39 | 322159 | 25.96 |
| 20 | 2763 | 4.42 | 2718 | 49 | 89.89 | 244329 | 24.87 |
| 21 | 2501 | 4 | 2456 | 45 | 100.56 | 246964 | 24.67 |
| 22 | 1961 | 3.14 | 1922 | 48 | 142.85 | 274567 | 25.08 |
| 23 | 1155 | 1.85 | 1141 | 47 | 111.3 | 126999 | 21.91 |

These are counts, not exposure-adjusted rates. Calendar coverage and train-service volumes differ. Missing or unparseable start timestamps appear as a missing group.

## Ten longest recorded disruptions

| rdt_id | rdt_lines | cause_en | start_time | end_time | duration_minutes |
| --- | --- | --- | --- | --- | --- |
| 5016 | — | weather circumstances | 2012-12-06 16:54:26 | 2013-01-20 19:01:29 | 64927 |
| 5032 | — | weather circumstances | 2012-12-07 22:59:15 | 2013-01-20 19:00:56 | 63121 |
| 43625 | Roermond - Sittard | damaged railway bridge | 2022-07-16 05:29:58 | 2022-08-16 16:31:29 | 45302 |
| 40522 | Berlin Ostbahnhof - Hengelo, Bielefeld Hbf - Hengelo, Hengelo - Oldenzaal | problems with the rolling stock | 2022-01-03 09:07:30 | 2022-02-02 22:43:56 | 44016 |
| 46998 | Leeuwarden - Stavoren | repair works | 2023-03-13 16:04:47 | 2023-04-11 10:04:04 | 41339 |
| 46508 | Groningen - Leeuwarden, Harlingen Haven - Leeuwarden, Leeuwarden - Stavoren, Leeuwarden - Zwolle | strike of Arriva staff | 2023-02-08 04:48:23 | 2023-03-08 01:07:41 | 40099 |
| 46509 | Delfzijl - Groningen, Groningen - Bad Nieuweschans, Groningen - Eemshaven, Groningen - Leer (Ostfriesland), Groningen - Leeuwarden, Groningen - Veendam, Groningen - Zwolle | strike of Arriva staff | 2023-02-08 04:48:27 | 2023-03-08 01:07:28 | 40099 |
| 46512 | Groningen - Leeuwarden | strike of Arriva staff | 2023-02-08 07:29:20 | 2023-03-07 07:22:52 | 38874 |
| 59232 | Liège-Guillemins - Maastricht, Maastricht - Maastricht Randwyck | staff strikes abroad | 2025-04-08 05:18:14 | 2025-04-29 23:49:11 | 31351 |
| 56860 | Heerlen - Maastricht | problems with the rolling stock | 2024-12-03 10:15:01 | 2024-12-25 00:15:23 | 31080 |

## Interpretation limits

- Records represent reported disruption events; they are not individual delayed trains or passenger journeys.
- Total recorded minutes sum event durations. Concurrent events can overlap, so these totals are not network downtime or passenger delay.
- The over-120-minute percentage uses positive finite durations as its denominator and a strict greater-than threshold.
- Associations are descriptive and do not establish causal effects.
- Full tables are exported as CSV files. Plots are saved in descriptive_plots.pdf.

