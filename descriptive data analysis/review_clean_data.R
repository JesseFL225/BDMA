##### BDMA Group Project, Part B #####
##### Review of the data preparation: raw data, cleaning and clean data #####
#
# Reviewer: Max (Analyst). Reviewed: the data engineer's work in data/ and
# "Data Cleaning/".
#
# Run from the repository root (the folder that contains data/):
#   Rscript "descriptive data analysis/review_clean_data.R"
#
# Input:  data/disruptions_2011_2025_raw.csv
#         data/disruptions_2011_2025_clean.csv
#         Data Cleaning/output/excluded_disruptions.csv
#         Data Cleaning/output/filter_audit.csv
#         Data Cleaning/output/endpoint_classification.csv
#         moddeling/09_modelkeuze_en_test/output/frozen_manifest.csv
# Output: descriptive data analysis/clean_analysis_output/review_checks.csv
#
# The script only reads the data. It never changes a file in data/.
# A check that passes prints TRUE; a check that fails stops the script, so that
# moddeling/run_all.R notices it. The numbers behind the review findings are
# saved in review_checks.csv.
#
# Reproduction of the cleaning itself was checked separately: running
# "Data Cleaning/clean_disruptions.R" in a copy of the repository gives the
# same 44,248 rows, IDs and values as the clean file in data/.


##### 1. Import the files #####

raw <- read.csv(
  "data/disruptions_2011_2025_raw.csv",
  na.strings = c("", "NA")
)
disruptions <- read.csv(
  "data/disruptions_2011_2025_clean.csv",
  na.strings = c("", "NA")
)
excluded <- read.csv(
  "Data Cleaning/output/excluded_disruptions.csv",
  na.strings = c("", "NA")
)
filter_audit <- read.csv("Data Cleaning/output/filter_audit.csv")

dim(raw)
dim(disruptions)
dim(excluded)
filter_audit[, c("step", "description", "removed_this_step", "remaining_rows")]


##### 2. Do the files add up? #####

# check() returns its input, so a passed check still prints TRUE. A failed check
# stops the script; the error message names the check.
check <- function(passed) {
  if (!isTRUE(passed)) {
    stop("This review check failed.")
  }
  return(passed)
}

# The row counts named in the report.
check(nrow(raw) == 62540)
check(nrow(disruptions) == 44248)

# Every raw record is either kept or excluded, never both.
check(nrow(disruptions) + nrow(excluded) == nrow(raw))
check(all(disruptions$rdt_id %in% raw$rdt_id))
check(all(excluded$rdt_id %in% raw$rdt_id))
check(sum(disruptions$rdt_id %in% excluded$rdt_id) == 0)

# One row is one disruption: no ID occurs twice.
check(sum(duplicated(raw$rdt_id)) == 0)
check(sum(duplicated(disruptions$rdt_id)) == 0)

# The filter table (Appendix B of the report) matches the excluded records.
check(sum(filter_audit$removed_this_step) == nrow(excluded))
table(excluded$first_exclusion_reason)

# The stacked raw file covers every year, and the year label fits the start time.
table(raw$source_year)
check(all(raw$source_year == as.integer(substr(raw$start_time, start = 1, stop = 4))))

# The clean file is the file that the models were tested on (same MD5 hash).
frozen_files <- read.csv("moddeling/09_modelkeuze_en_test/output/frozen_manifest.csv")
frozen_hash <- frozen_files$md5[frozen_files$path == "data/disruptions_2011_2025_clean.csv"]
clean_hash <- unname(tools::md5sum("data/disruptions_2011_2025_clean.csv"))
check(clean_hash == frozen_hash)


##### 3. Is the clean file valid? #####

## 3.1 Missing values

colSums(is.na(raw))
colSums(is.na(disruptions))

## 3.2 The target: duration in minutes

summary(disruptions$duration_minutes)
check(all(disruptions$duration_minutes >= 1 & disruptions$duration_minutes <= 1440))
check(all(disruptions$duration_minutes %% 1 == 0))

# Recalculate the duration from the start and end time. Both are stored in UTC.
start_time <- as.POSIXct(disruptions$start_time, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
end_time <- as.POSIXct(disruptions$end_time, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
check(sum(is.na(start_time)) == 0)
check(sum(is.na(end_time)) == 0)

calculated_minutes <- as.numeric(difftime(end_time, start_time, units = "mins"))
max(abs(disruptions$duration_minutes - calculated_minutes))
check(all(abs(disruptions$duration_minutes - calculated_minutes) <= 1))

## 3.3 The time columns are local Dutch time

local_year <- as.integer(format(start_time, format = "%Y", tz = "Europe/Amsterdam"))
local_month <- as.integer(format(start_time, format = "%m", tz = "Europe/Amsterdam"))
local_weekday <- as.integer(format(start_time, format = "%u", tz = "Europe/Amsterdam"))
local_hour <- as.integer(format(start_time, format = "%H", tz = "Europe/Amsterdam"))

check(all(local_year == disruptions$start_year))
check(all(local_month == disruptions$start_month))
check(all(local_weekday == disruptions$start_weekday))
check(all(local_hour == disruptions$start_hour))


##### 4. What do the filters remove? #####

## 4.1 Removed records per filter and year

table(excluded$first_exclusion_reason, excluded$source_year)

removed_pct <- round(nrow(excluded) / nrow(raw) * 100, digits = 1)
removed_pct

## 4.2 Filter 12: reported duration differs from end time minus start time

mismatch <- subset(excluded, first_exclusion_reason == "duration_mismatch")
nrow(mismatch)

# All of these records are from before 2017.
range(mismatch$source_year)

# difference_minutes = reported duration minus (end time - start time).
summary(mismatch$difference_minutes)

# In almost every case the reported duration is the shorter one.
reported_is_shorter <- sum(mismatch$difference_minutes < 0)
reported_is_shorter
round(reported_is_shorter / nrow(mismatch) * 100, digits = 1)

# So the two fields differ in a systematic way before 2017 (a different
# definition), not through random errors. The filter keeps a small part of
# these years, and the kept part is not typical: it lasts longer.
early_raw <- subset(raw, source_year <= 2016)
early_kept <- subset(disruptions, start_year <= 2016)
nrow(early_raw)
nrow(early_kept)
round(nrow(early_kept) / nrow(early_raw) * 100, digits = 1)

median(early_kept$duration_minutes)
median(mismatch$duration_minutes)

## 4.3 Filter 5: foreign route or station

foreign <- subset(excluded, first_exclusion_reason == "international_route")
nrow(foreign)

# Does the standardised route (rdt_lines) contain a foreign end point?
endpoint_classes <- read.csv("Data Cleaning/output/endpoint_classification.csv")
foreign_endpoints <- endpoint_classes$endpoint[endpoint_classes$classification == "foreign"]
foreign_endpoints

foreign$has_foreign_endpoint <- FALSE
for (endpoint in foreign_endpoints) {
  found <- grepl(endpoint, foreign$rdt_lines, fixed = TRUE)
  foreign$has_foreign_endpoint[found] <- TRUE
}
table(foreign$has_foreign_endpoint)

# The other records were removed because a foreign name occurs in the text.
text_only <- subset(foreign, has_foreign_endpoint == FALSE)
nrow(text_only)

# Most of these have a Dutch standardised route: the disruption is in the
# Netherlands, but NS announced it for an international train service.
dutch_route_foreign_text <- subset(text_only, !is.na(rdt_lines))
nrow(dutch_route_foreign_text)
head(sort(table(dutch_route_foreign_text$ns_lines), decreasing = TRUE), n = 5)

## 4.4 Filter 8: duration of zero minutes

zero_duration <- subset(excluded, first_exclusion_reason == "invalid_duration")
nrow(zero_duration)
table(zero_duration$duration_minutes, useNA = "ifany")
range(zero_duration$source_year)

# Records of one or two minutes are kept. They may be messages that NS
# withdrew quickly, like the zero-minute records.
very_short <- subset(disruptions, duration_minutes <= 2)
nrow(very_short)
round(nrow(very_short) / nrow(disruptions) * 100, digits = 1)

## 4.5 Filter 11: longer than 24 hours (a rule that uses the outcome)

over_24_hours <- subset(excluded, first_exclusion_reason == "duration_over_limit")
nrow(over_24_hours)
sort(table(over_24_hours$cause_group), decreasing = TRUE)


##### 5. Points about the clean data that the report should mention #####

## 5.1 Station information is missing for every disruption before 2017

table(
  stations_missing = disruptions$stations_missing,
  before_2017 = disruptions$start_year <= 2016
)

## 5.2 The route is never missing, so the feature routes_missing is always 0

sum(is.na(disruptions$rdt_lines_id))

## 5.3 The stored cause is the last cause that NS used

# The statistical cause keeps the original cause when NS changed it to a
# general one. Records where the two differ had their cause changed.
revised_cause <- subset(disruptions, cause_nl != statistical_cause_nl)
unchanged_cause <- subset(disruptions, cause_nl == statistical_cause_nl)
nrow(revised_cause)
round(nrow(revised_cause) / nrow(disruptions) * 100, digits = 2)
head(sort(table(revised_cause$cause_en), decreasing = TRUE), n = 3)

# A changed cause goes together with a long disruption.
median(revised_cause$duration_minutes)
median(unchanged_cause$duration_minutes)
round(mean(revised_cause$duration_minutes > 60) * 100, digits = 1)
round(mean(unchanged_cause$duration_minutes > 60) * 100, digits = 1)

## 5.4 The cause is unknown more often in the validation and test year

disruptions$unknown_cause <- 0
disruptions$unknown_cause[disruptions$cause_group == "unknown"] <- 1
unknown_by_year <- aggregate(unknown_cause ~ start_year, data = disruptions, FUN = mean)
unknown_by_year$unknown_cause <- round(unknown_by_year$unknown_cause * 100, digits = 1)
unknown_by_year

## 5.5 Records with the same start second and route: possible double messages

start_and_route <- disruptions[, c("start_time", "rdt_lines")]
same_start_and_route <- duplicated(start_and_route) |
  duplicated(start_and_route, fromLast = TRUE)
sum(same_start_and_route)


##### 6. Save the numbers behind the review #####

review_checks <- data.frame(
  check = c(
    "Raw records",
    "Clean disruptions",
    "Excluded records",
    "Excluded records (% of raw)",
    "Filter 12: records removed (duration mismatch)",
    "Filter 12: reported duration shorter than end minus start (%)",
    "Filter 12: median difference (minutes)",
    "2011-2016: share of raw records kept (%)",
    "2011-2016: median duration of kept records (minutes)",
    "2011-2016: median duration of records removed by filter 12 (minutes)",
    "Filter 5: records removed (foreign route or station)",
    "Filter 5: removed on a foreign name in the text only",
    "Filter 5: of these, with a Dutch standardised route",
    "Filter 8: records removed (duration of zero minutes or missing)",
    "Clean data: disruptions of one or two minutes",
    "Clean data: disruptions of one or two minutes (%)",
    "Filter 11: records removed (longer than 24 hours)",
    "Clean data: disruptions without station information",
    "Clean data: disruptions before 2017",
    "Clean data: disruptions without a route",
    "Clean data: stored cause differs from statistical cause",
    "Median duration when the cause was changed (minutes)",
    "Median duration when the cause was not changed (minutes)",
    "Clean data: records sharing start second and route"
  ),
  value = c(
    nrow(raw),
    nrow(disruptions),
    nrow(excluded),
    removed_pct,
    nrow(mismatch),
    round(reported_is_shorter / nrow(mismatch) * 100, digits = 1),
    median(mismatch$difference_minutes),
    round(nrow(early_kept) / nrow(early_raw) * 100, digits = 1),
    median(early_kept$duration_minutes),
    median(mismatch$duration_minutes),
    nrow(foreign),
    nrow(text_only),
    nrow(dutch_route_foreign_text),
    nrow(zero_duration),
    nrow(very_short),
    round(nrow(very_short) / nrow(disruptions) * 100, digits = 1),
    nrow(over_24_hours),
    sum(disruptions$stations_missing),
    nrow(early_kept),
    sum(is.na(disruptions$rdt_lines_id)),
    nrow(revised_cause),
    median(revised_cause$duration_minutes),
    median(unchanged_cause$duration_minutes),
    sum(same_start_and_route)
  )
)
review_checks

output_folder <- "descriptive data analysis/clean_analysis_output"
dir.create(output_folder, recursive = TRUE, showWarnings = FALSE)
write.csv(
  review_checks,
  file.path(output_folder, "review_checks.csv"),
  row.names = FALSE
)
