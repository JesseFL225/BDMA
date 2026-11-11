# Descriptive analysis of the RAW disruption dataset (base R only).
# In RStudio: open Train-disruptions.Rproj, then source this file.
# In a terminal from the project root:
# Rscript "descriptive data analysis/raw_descriptive_analysis.R"
# Outputs: descriptive data analysis/raw_analysis_output/
# The source CSV is read only; no observations are removed or overwritten.

project_root <- if (file.exists("disruptions_2011_2025_raw.csv")) "." else ".."
input_file <- file.path(project_root, "disruptions_2011_2025_raw.csv")
output_dir <- file.path(project_root, "descriptive data analysis", "raw_analysis_output")
if (!file.exists(input_file)) stop("Open the project folder before running this script.")
dir.create(output_dir, showWarnings = FALSE)
raw <- read.csv(input_file, na.strings = c("", "NA"),
                stringsAsFactors = FALSE, check.names = FALSE)
n <- nrow(raw)
if (n == 0) stop("The input file contains no observations.")

# 1. Variable dictionary. Interpretations are inferred from field names and
# observed values; an official source codebook was not supplied.
descriptions <- c(
  rdt_id = "Record identifier; uniqueness is checked below.",
  ns_lines = "Affected railway route(s), using the NS naming field.",
  rdt_lines = "Affected railway route(s), using the RDT naming field.",
  rdt_lines_id = "Route identifier(s); stored as text because a cell may contain multiple IDs.",
  rdt_station_names = "Affected station name(s), where recorded.",
  rdt_station_codes = "Affected station code(s), where recorded.",
  cause_nl = "Reported disruption cause in Dutch.",
  cause_en = "Reported disruption cause in English.",
  statistical_cause_nl = "Statistical cause label in Dutch; exact coding rules are unverified.",
  statistical_cause_en = "Statistical cause label in English; exact coding rules are unverified.",
  cause_group = "Broad category grouping disruption causes.",
  start_time = "Recorded start timestamp; source timezone is unspecified.",
  end_time = "Recorded end timestamp; source timezone is unspecified.",
  duration_minutes = "Recorded disruption duration in minutes.",
  source_year = "Year label of the source data; compared with the start timestamp below."
)
dictionary <- data.frame(
  variable = names(raw),
  imported_type = vapply(raw, function(x) paste(class(x), collapse = "/"), character(1)),
  meaning = unname(descriptions[names(raw)]),
  nonmissing = vapply(raw, function(x) sum(!is.na(x)), integer(1)),
  missing = vapply(raw, function(x) sum(is.na(x)), integer(1)),
  missing_pct = vapply(raw, function(x) round(mean(is.na(x)) * 100, 2), numeric(1)),
  distinct_nonmissing = vapply(raw, function(x) length(unique(x[!is.na(x)])), integer(1)),
  row.names = NULL
)

# 2. Derived values are kept separately from the raw data.
# UTC is used as a neutral clock for parsing naive timestamps, NOT as a claim
# about their actual timezone. DST may affect comparisons with stored duration.
start <- as.POSIXct(raw$start_time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
end <- as.POSIXct(raw$end_time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
elapsed <- as.numeric(difftime(end, start, units = "mins"))
duration <- raw$duration_minutes
valid_duration <- !is.na(duration) & is.finite(duration) & duration > 0
start_year <- as.integer(format(start, "%Y", tz = "UTC"))
month <- as.integer(format(start, "%m", tz = "UTC"))
weekday <- as.integer(format(start, "%u", tz = "UTC"))
hour <- as.integer(format(start, "%H", tz = "UTC"))

# Numeric summaries retain all recorded numeric values, including invalid ones.
numeric_summary <- function(x) {
  x <- x[!is.na(x) & is.finite(x)]
  if (!length(x)) return(rep(NA_real_, 10))
  c(length(x), min(x), quantile(x, .25, names = FALSE), median(x),
    mean(x), quantile(x, .75, names = FALSE), quantile(x, .90, names = FALSE),
    quantile(x, .95, names = FALSE), max(x), sd(x))
}
duration_summary <- data.frame(
  measure = c("Nonmissing finite observations", "Minimum", "25th percentile", "Median",
              "Mean", "75th percentile", "90th percentile", "95th percentile", "Maximum", "Standard deviation"),
  minutes_or_count = round(numeric_summary(duration), 2)
)

quality <- data.frame(
  check = c("Rows", "Columns", "Exact duplicate rows (after first occurrence)",
            "Repeated nonmissing record IDs (after first occurrence)",
            "Missing durations", "Zero durations", "Negative durations", "Nonfinite nonmissing durations",
            "Nonmissing start timestamps that fail parsing", "Nonmissing end timestamps that fail parsing",
            "End before start", "Source year differs from start year",
            "Duration differs from timestamp interval by more than 1 minute",
            "Positive durations over 24 hours", "Positive durations over 7 days"),
  count = c(n, ncol(raw), sum(duplicated(raw)),
            sum(duplicated(raw$rdt_id[!is.na(raw$rdt_id)])),
            sum(is.na(duration)), sum(duration == 0, na.rm = TRUE), sum(duration < 0, na.rm = TRUE),
            sum(!is.na(duration) & !is.finite(duration)),
            sum(!is.na(raw$start_time) & is.na(start)), sum(!is.na(raw$end_time) & is.na(end)),
            sum(elapsed < 0, na.rm = TRUE), sum(raw$source_year != start_year, na.rm = TRUE),
            sum(abs(duration - elapsed) > 1, na.rm = TRUE),
            sum(duration > 1440, na.rm = TRUE), sum(duration > 10080, na.rm = TRUE))
)

# Every row is a recorded event; missing group labels remain visible.
# Duration aggregates use positive finite durations only, with denominators shown.
group_summary <- function(group) {
  group <- as.character(group)
  group[is.na(group) | trimws(group) == ""] <- "(Missing)"
  result <- lapply(sort(unique(group)), function(label) {
    idx <- group == label
    x <- duration[idx & valid_duration]
    data.frame(group = label, records = sum(idx), pct_of_all_records = round(sum(idx) / n * 100, 2),
               valid_duration_n = length(x),
               median_minutes = if (length(x)) round(median(x), 2) else NA_real_,
               mean_minutes = if (length(x)) round(mean(x), 2) else NA_real_,
               total_recorded_minutes = sum(x),
               pct_over_120_minutes = if (length(x)) round(mean(x > 120) * 100, 2) else NA_real_)
  })
  do.call(rbind, result)
}
by_year <- group_summary(raw$source_year)
by_cause_group <- group_summary(raw$cause_group)
by_cause_group <- by_cause_group[order(-by_cause_group$records), ]
by_cause <- group_summary(raw$cause_en)
by_cause <- by_cause[order(-by_cause$records), ]
# Route cells can contain multiple routes. This table counts complete field
# values/combinations, not independently separated railway lines.
by_route <- group_summary(raw$rdt_lines)
by_route <- by_route[order(-by_route$records), ]
by_month <- group_summary(ifelse(is.na(month), NA, sprintf("%02d", month)))
by_weekday <- group_summary(ifelse(is.na(weekday), NA,
  paste0(weekday, " ", c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")[weekday])))
by_hour <- group_summary(ifelse(is.na(hour), NA, sprintf("%02d", hour)))

# Observed timestamp ranges help identify partial-year coverage. They do not
# establish whether collection was complete between the first and last record.
coverage <- do.call(rbind, lapply(sort(unique(raw$source_year[!is.na(raw$source_year)])), function(y) {
  x <- start[!is.na(raw$source_year) & raw$source_year == y & !is.na(start)]
  data.frame(source_year = y,
             first_recorded_start = if (length(x)) format(min(x), tz = "UTC") else NA_character_,
             last_recorded_start = if (length(x)) format(max(x), tz = "UTC") else NA_character_)
}))
longest <- raw[order(duration, decreasing = TRUE, na.last = NA),
               c("rdt_id", "rdt_lines", "cause_en", "start_time", "end_time", "duration_minutes")]
longest <- head(longest, 10)

tables <- list(variable_dictionary = dictionary, data_quality = quality,
               duration_summary = duration_summary, yearly_summary = by_year,
               yearly_coverage = coverage, cause_group_summary = by_cause_group,
               cause_summary = by_cause, route_combination_summary = by_route,
               monthly_summary = by_month, weekday_summary = by_weekday,
               hourly_summary = by_hour, longest_disruptions = longest)
for (name in names(tables)) {
  write.csv(tables[[name]], file.path(output_dir, paste0(name, ".csv")), row.names = FALSE, na = "")
}

# 3. Export readable tables and interpretation notes in a Markdown report.
markdown_table <- function(d) {
  clean <- function(x) {
    x <- as.character(x)
    x[is.na(x)] <- "—"
    x <- gsub("|", "/", x, fixed = TRUE)
    gsub("[\r\n]", " ", x)
  }
  d[] <- lapply(d, clean)
  c(paste0("| ", paste(names(d), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(d)), collapse = " | "), " |"),
    apply(d, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |")))
}
report <- c(
  "# Raw train disruption data: descriptive analysis", "",
  sprintf("Input: `%s`. Contains %s records and %s variables. No raw records were removed.", input_file, format(n, big.mark = ","), ncol(raw)), "",
  "## Main findings", "",
  sprintf("- The median recorded duration is %.0f minutes, compared with a mean of %.2f minutes (including zero durations, excluding missing values). The higher mean indicates a right-skewed distribution.", median(duration, na.rm = TRUE), mean(duration, na.rm = TRUE)),
  sprintf("- The longest recorded duration is %s minutes (%.1f days), so extreme records warrant review.", format(max(duration, na.rm = TRUE), big.mark = ","), max(duration, na.rm = TRUE) / 1440),
  sprintf("- %s is the most frequent cause group: %s records (%.2f%%).", by_cause_group$group[1], format(by_cause_group$records[1], big.mark = ","), by_cause_group$pct_of_all_records[1]),
  sprintf("- Among cause groups with positive durations, %s has the longest median duration (%.0f minutes).", by_cause_group$group[which.max(by_cause_group$median_minutes)], max(by_cause_group$median_minutes, na.rm = TRUE)),
  sprintf("- Annual recorded counts range from %s to %s. These counts are not adjusted for service volumes or changes in reporting.", format(min(by_year$records), big.mark = ","), format(max(by_year$records), big.mark = ",")),
  "- Inspect the annual coverage table before year-to-year comparisons; an early last observation can indicate a coverage gap.",
  sprintf("- %s durations are zero and %s are missing. %s recorded durations differ from the naive timestamp interval by more than one minute; investigate the source definition before recalculating durations.", sum(duration == 0, na.rm = TRUE), sum(is.na(duration)), format(sum(abs(duration - elapsed) > 1, na.rm = TRUE), big.mark = ",")), "",
  "## Variable meanings and completeness", "",
  "Definitions are inferred from column names and observed values; an official codebook was not supplied. Missingness treats empty CSV cells and literal NA as missing. Route and station fields may contain multiple values.", "",
  markdown_table(dictionary), "",
  "## Data quality", "", markdown_table(quality), "",
  "Zero and negative durations are quality flags, not automatically errors to delete. Extremely long events also require investigation before exclusion. Timestamp comparisons use naive clock differences because the original timezone is unspecified.", "",
  "## Duration distribution", "", markdown_table(duration_summary), "",
  "This distribution includes all recorded finite durations. The group tables below calculate duration statistics only for positive finite durations. Compare median and mean to assess skew; inspect the longest records before interpreting extremes.", "",
  "## Annual patterns", "", markdown_table(by_year), "",
  "### Observed annual coverage", "", markdown_table(coverage), "",
  "First and last timestamps indicate the observed range, not verified collection completeness. Differences in collection, coding and service volumes may affect comparisons across years.", "",
  "## Broad cause categories", "", markdown_table(by_cause_group), "",
  "## Most frequent reported causes (top 15)", "", markdown_table(head(by_cause, 15)), "",
  "## Most frequent route field values (top 10)", "", markdown_table(head(by_route, 10)), "",
  "Each route value is counted as recorded, including combinations. Counts cannot establish line reliability without the number of services operated.", "",
  "## Month of start (pooled across years)", "", markdown_table(by_month), "",
  "## Weekday of start (pooled across years)", "", markdown_table(by_weekday), "",
  "## Hour of start (pooled across years)", "", markdown_table(by_hour), "",
  "These are counts, not exposure-adjusted rates. Calendar coverage and train-service volumes differ. Missing or unparseable start timestamps appear as a missing group.", "",
  "## Ten longest recorded disruptions", "", markdown_table(longest), "",
  "## Interpretation limits", "",
  "- Records represent reported disruption events; they are not individual delayed trains or passenger journeys.",
  "- Total recorded minutes sum event durations. Concurrent events can overlap, so these totals are not network downtime or passenger delay.",
  "- The over-120-minute percentage uses positive finite durations as its denominator and a strict greater-than threshold.",
  "- Associations are descriptive and do not establish causal effects.",
  "- Full tables are exported as CSV files. Plots are saved in descriptive_plots.pdf.", ""
)
writeLines(report, file.path(output_dir, "raw_descriptive_report.md"))

# 4. Four plots, one per page. No external packages are required.
pdf(file.path(output_dir, "descriptive_plots.pdf"), width = 10, height = 7)
par(mar = c(5, 5, 4, 2))
barplot(by_year$records, names.arg = by_year$group, las = 2,
        col = "steelblue", main = "Recorded disruptions by source year", ylab = "Records")
hist(log10(duration[valid_duration]), breaks = 50, col = "steelblue", border = "white",
     main = "Duration distribution (positive finite durations)",
     xlab = "log10(duration in minutes)", ylab = "Records")
par(mar = c(5, 12, 4, 2))
top_groups <- head(by_cause_group, 12)
barplot(rev(top_groups$records), names.arg = rev(top_groups$group), horiz = TRUE,
        las = 1, col = "steelblue", main = "Most frequent cause groups", xlab = "Records", cex.names = .8)
par(mar = c(5, 5, 4, 2))
barplot(by_hour$records, names.arg = by_hour$group, col = "steelblue",
        main = "Recorded disruptions by start hour", xlab = "Recorded hour (timezone unspecified)", ylab = "Records")
dev.off()

cat("Analysis complete. Outputs saved in:", normalizePath(output_dir), "\n")
print(duration_summary, row.names = FALSE)
print(quality, row.names = FALSE)
