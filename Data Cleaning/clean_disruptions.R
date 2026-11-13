# Reproducible, conservative domestic-disruption selection (base R only).
# Run from the repository root: Rscript "Data Cleaning/clean_disruptions.R"
# Raw input is NEVER overwritten. The clean CSV in data/ is regenerated. All exclusions are logged.
# An exclusion is not necessarily an error: scope and uncertainty are separate.

MAX_DURATION_MINUTES <- 1440 # Analysis scope: at most 24 hours; not proof of error.
MAX_DIFFERENCE_MINUTES <- 1 # Allows rounding to whole minutes.
TIMEZONE <- "Europe/Amsterdam"
INPUT <- "data/disruptions_2011_2025_raw.csv"
OUTPUT <- "Data Cleaning/output"
CLEAN_OUTPUT <- "data/disruptions_2011_2025_clean.csv"

stopifnot(file.exists(INPUT))
dir.create(OUTPUT, recursive = TRUE, showWarnings = FALSE)
raw <- read.csv(INPUT, colClasses = "character", na.strings = c("", "NA"),
                check.names = FALSE, fileEncoding = "UTF-8")
expected <- c("rdt_id", "ns_lines", "rdt_lines", "rdt_lines_id",
 "rdt_station_names", "rdt_station_codes", "cause_nl", "cause_en",
 "statistical_cause_nl", "statistical_cause_en", "cause_group",
 "start_time", "end_time", "duration_minutes", "source_year")
stopifnot(identical(names(raw), expected), nrow(raw) > 0)
x <- raw
for (nm in names(x)) {
  x[[nm]] <- trimws(gsub("[[:space:]]+", " ", x[[nm]]))
  x[[nm]][!is.na(x[[nm]]) & tolower(x[[nm]]) %in% c("", "na", "nan", "null", "n/a")] <- NA
}
n <- nrow(x)
safe <- function(v) ifelse(is.na(v), "", v)
split_list <- function(v) lapply(safe(v), function(s) {
  if (!nzchar(s)) character() else trimws(strsplit(s, ",", fixed = TRUE)[[1]])
})

# Explicit endpoint allowlist: unknown future endpoints are quarantined, never
# silently assumed to be Dutch. Bad Nieuweschans and Oldenzaal ARE Dutch.
nl_endpoints <- c("'s-Hertogenbosch", "Alkmaar", "Almelo", "Almere Oostvaarders",
 "Alphen a/d Rijn", "Amersfoort", "Amsterdam Centraal", "Apeldoorn", "Arnhem Centraal",
 "Baarn", "Bad Nieuweschans", "Breda", "Breda (HSL)", "Delfzijl", "Den Haag Centraal",
 "Den Haag HS", "Den Helder", "Deventer", "Dordrecht", "Ede-Wageningen", "Eemshaven",
 "Eindhoven", "Emmen", "Enkhuizen", "Enschede", "Geldermalsen", "Gouda", "Groningen",
 "Haarlem", "Harlingen Haven", "Heerlen", "Hengelo", "Hilversum", "Hoek van Holland Strand",
 "Hoorn", "Kampen", "Kerkrade Centrum", "Leeuwarden", "Leiden Centraal", "Lelystad Centrum",
 "Maastricht", "Maastricht Randwyck", "Mariënberg", "Nijmegen", "Oldenzaal", "Rhenen",
 "Roermond", "Roosendaal", "Rotterdam Centraal", "Rotterdam Centraal (HSL)",
 "Schiphol Airport", "Schiphol Airport (HSL)", "Sittard", "Stavoren", "Tiel", "Tilburg",
 "Uitgeest", "Utrecht Centraal", "Utrecht Maliebaan", "Veendam", "Venlo", "Vlissingen",
 "Winterswijk", "Woerden", "Zaandam", "Zandvoort aan Zee", "Zutphen", "Zwolle")
foreign_endpoints <- c("Aachen Hbf", "Antwerpen-Centraal", "Basel SBB", "Berlin Ostbahnhof",
 "Bielefeld Hbf", "Brussel-Zuid/Midi", "Brussels Airport-Zaventem", "Dortmund Hbf",
 "Düsseldorf Hbf", "Frankfurt (M) Hbf", "Gronau (Westf.)", "Hamm (Westf.)", "Innsbruck Hbf",
 "Leer (Ostfriesland)", "Liège-Guillemins", "Münster (Westf.) Hbf", "Paris-Nord",
 "Wien Hbf", "Zürich HB")
route_lists <- split_list(x$rdt_lines)
endpoints <- lapply(route_lists, function(routes) unlist(strsplit(routes, " - ", fixed = TRUE)))
all_endpoints <- sort(unique(unlist(endpoints)))
endpoint_audit <- data.frame(endpoint = all_endpoints,
 classification = ifelse(all_endpoints %in% nl_endpoints, "NL",
                  ifelse(all_endpoints %in% foreign_endpoints, "foreign", "unresolved")))
foreign_pattern <- paste0("(?i)(?<![[:alpha:]])(", paste(c(
 "Aachen", "Antwerpen", "Antwerp", "Basel", "Berlin", "Berlijn", "Bielefeld",
 "Brussel", "Brussels", "Bruxelles", "Zaventem", "Dortmund", "Düsseldorf", "Dusseldorf",
 "Frankfurt", "Gronau", "Hamm", "Innsbruck", "Leer", "Liège", "Liege", "Luik",
 "Münster", "Munster", "Paris", "Parijs", "Wien", "Vienna", "Wenen", "Zürich", "Zurich",
 "London", "Londen", "St\\.? Pancras", "Ebbsfleet", "Ashford", "Calais", "Lille",
 "Köln", "Koln", "Keulen", "Hannover", "Bad Bentheim", "Emmerich", "Mönchengladbach",
 "Monchengladbach", "Kaldenkirchen", "Herzogenrath", "Hasselt", "Puurs", "Essen",
 "Duisburg", "Oberhausen", "Duitsland", "België", "Belgie", "Engeland", "Frankrijk",
 "Germany", "Belgium", "England", "France", "Oostenrijk", "Zwitserland"), collapse = "|"),
 ")(?![[:alpha:]])")
geo_text <- paste(safe(x$ns_lines), safe(x$rdt_lines), safe(x$rdt_station_names))
foreign <- vapply(endpoints, function(e) any(e %in% foreign_endpoints), logical(1)) |
           grepl(foreign_pattern, geo_text, perl = TRUE)
geo_evidence <- vapply(seq_len(n), function(i) {
  m <- regmatches(geo_text[i], gregexpr(foreign_pattern, geo_text[i], perl = TRUE))[[1]]
  paste(unique(c(intersect(endpoints[[i]], foreign_endpoints), m)), collapse = "; ")
}, character(1))
unresolved_route <- vapply(seq_len(n), function(i) {
  routes <- route_lists[[i]]
  !length(routes) || any(lengths(strsplit(routes, " - ", fixed = TRUE)) != 2) ||
    any(!endpoints[[i]] %in% c(nl_endpoints, foreign_endpoints)) ||
    is.na(x$rdt_lines_id[i]) || length(routes) != length(split_list(x$rdt_lines_id[i])[[1]])
}, logical(1))

# Explicit test and information-only patterns, not generic words like "werkzaamheden".
text <- apply(x[, c("ns_lines", "rdt_lines", "cause_nl", "cause_en",
                   "statistical_cause_nl", "statistical_cause_en")], 1, paste, collapse = " ")
test_message <- grepl("(?i)\\b(testbericht(en)?|testmelding(en)?|test message(s)?|dummy|proefbericht)\\b", text, perl = TRUE)
information_message <- grepl(paste(c("reisplanner", "reisinformatie", "vertrektijd",
 "meer info", "extra info", "aanvullende info", "extra uitleg", "toelichting",
 "app en site", "storingen-informatie", "tijdelijk geen actuele informatie"), collapse = "|"),
 safe(x$ns_lines), ignore.case = TRUE)

# Detect ambiguous/nonexistent local times rather than silently picking a DST fold.
parse_time <- function(v) as.POSIXct(v, format = "%Y-%m-%d %H:%M:%S", tz = TIMEZONE)
start <- parse_time(x$start_time)
end <- parse_time(x$end_time)
bad_time <- function(v, t) {
  rendered <- format(t, "%Y-%m-%d %H:%M:%S", tz = TIMEZONE)
  ambiguous <- safe(format(t - 3600, "%Y-%m-%d %H:%M:%S", tz = TIMEZONE)) == safe(v) |
               safe(format(t + 3600, "%Y-%m-%d %H:%M:%S", tz = TIMEZONE)) == safe(v)
  is.na(v) | is.na(t) | safe(rendered) != safe(v) | ambiguous
}
duration <- suppressWarnings(as.numeric(x$duration_minutes))
elapsed <- as.numeric(difftime(end, start, units = "mins"))
difference <- duration - elapsed
year <- suppressWarnings(as.integer(x$source_year))
start_year <- as.integer(format(start, "%Y", tz = TIMEZONE))
id_bad <- is.na(x$rdt_id) | !grepl("^[1-9][0-9]*$", safe(x$rdt_id))
exact_duplicate <- duplicated(x)
# Conflicting duplicate IDs are all quarantined; exact duplicate copies keep first.
unique_records <- !exact_duplicate & !id_bad
conflict_ids <- names(which(table(x$rdt_id[unique_records]) > 1))

flags <- data.frame(
 exact_duplicate = exact_duplicate,
 invalid_or_conflicting_id = id_bad | x$rdt_id %in% conflict_ids,
 test_message = test_message,
 information_message = information_message,
 international_route = foreign,
 unresolved_route = unresolved_route,
 invalid_or_ambiguous_time = bad_time(x$start_time, start) | bad_time(x$end_time, end),
 invalid_duration = !is.finite(duration) | duration <= 0,
 end_not_after_start = is.finite(elapsed) & elapsed <= 0,
 invalid_source_year = is.na(year) | is.na(start_year) | year != start_year | year < 2011 | year > 2025,
 duration_over_limit = (is.finite(duration) & duration > MAX_DURATION_MINUTES) |
                       (is.finite(elapsed) & elapsed > MAX_DURATION_MINUTES),
 duration_mismatch = is.finite(difference) & abs(difference) > MAX_DIFFERENCE_MINUTES
)
flags[is.na(flags)] <- TRUE # Fail closed for unresolved validity checks.
labels <- c("Exact duplicate rows", "Invalid or conflicting IDs", "Test messages",
 "Information and follow-up messages", "Foreign route or station",
 "Route cannot be classified reliably", "Missing/invalid/ambiguous time",
 "Missing, non-finite or non-positive duration", "End not after start",
 "Invalid or inconsistent source year", "Reported or calculated duration above 24 hours",
 "Duration difference above 1 minute")
active <- rep(TRUE, n)
first_reason <- rep(NA_character_, n)
audit <- data.frame()
for (j in seq_along(flags)) {
  remove <- active & flags[[j]]
  audit <- rbind(audit, data.frame(step = j, rule = names(flags)[j], description = labels[j],
    input_rows = sum(active), matching_all_raw = sum(flags[[j]]),
    removed_this_step = sum(remove), remaining_rows = sum(active) - sum(remove)))
  first_reason[remove] <- names(flags)[j]
  active[remove] <- FALSE
}
all_reasons <- apply(flags, 1, function(v) paste(names(flags)[v], collapse = ";"))

clean <- x[active, ]
clean$duration_minutes <- duration[active]
clean$source_year <- year[active]
clean$start_time <- format(start[active], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
clean$end_time <- format(end[active], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
clean$calculated_minutes <- elapsed[active]
clean$difference_minutes <- difference[active]
clean$start_year <- start_year[active]
clean$start_month <- as.integer(format(start[active], "%m", tz = TIMEZONE))
clean$start_weekday <- as.integer(format(start[active], "%u", tz = TIMEZONE))
clean$start_hour <- as.integer(format(start[active], "%H", tz = TIMEZONE))
clean$long_disruption <- as.integer(duration[active] > 60)
# Preserve missingness; these indicators are not a mandatory model feature set.
clean$stations_missing <- is.na(clean$rdt_station_codes)
clean$cause_missing <- is.na(clean$cause_nl)
clean$cause_group[is.na(clean$cause_group)] <- "unknown"
excluded <- cbind(raw[!active, ], source_csv_row = which(!active) + 1L,
 first_exclusion_reason = first_reason[!active], all_exclusion_reasons = all_reasons[!active],
 foreign_evidence = geo_evidence[!active], calculated_minutes = elapsed[!active],
 difference_minutes = difference[!active])
counts <- function(mask) as.integer(table(factor(year[mask], levels = 2011:2025)))
yearly <- data.frame(year = 2011:2025, raw_rows = counts(rep(TRUE, n)), clean_rows = counts(active))
yearly$removed_rows <- yearly$raw_rows - yearly$clean_rows
yearly$retained_pct <- round(100 * yearly$clean_rows / yearly$raw_rows, 2)
missingness <- data.frame(column = names(clean), missing = vapply(clean, function(v) sum(is.na(v)), integer(1)))
non_duration_rules <- setdiff(names(flags), c("duration_over_limit", "duration_mismatch"))
otherwise_eligible <- rowSums(flags[, non_duration_rules]) == 0
sensitivity <- expand.grid(max_duration_minutes = c(1440, 10080), max_difference_minutes = c(1, 5, 60))
sensitivity$retained_rows <- vapply(seq_len(nrow(sensitivity)), function(i) sum(
 otherwise_eligible & is.finite(difference) & abs(difference) <= sensitivity$max_difference_minutes[i] &
 duration <= sensitivity$max_duration_minutes[i] & elapsed <= sensitivity$max_duration_minutes[i], na.rm = TRUE), integer(1))

# Invariants verify the actual selection and preservation of input records.
stopifnot(nrow(clean) + nrow(excluded) == n, !anyDuplicated(clean$rdt_id),
 sum(audit$removed_this_step) == nrow(excluded), !any(rowSums(flags[active, ]) > 0),
 all(clean$duration_minutes > 0 & clean$duration_minutes <= MAX_DURATION_MINUTES),
 all(abs(clean$difference_minutes) <= MAX_DIFFERENCE_MINUTES),
 all(clean$long_disruption == as.integer(clean$duration_minutes > 60)))
write <- function(object, name) write.csv(object, file.path(OUTPUT, name), row.names = FALSE,
                                          na = "NA", fileEncoding = "UTF-8")
write.csv(clean, CLEAN_OUTPUT, row.names = FALSE, na = "NA", fileEncoding = "UTF-8")
write(excluded, "excluded_disruptions.csv")
write(audit, "filter_audit.csv")
write(yearly, "yearly_retention.csv")
write(missingness, "remaining_missingness.csv")
write(endpoint_audit, "endpoint_classification.csv")
write(sensitivity, "threshold_sensitivity.csv")
saved <- read.csv(CLEAN_OUTPUT, colClasses = "character")
stopifnot(nrow(saved) == nrow(clean), identical(saved$rdt_id, clean$rdt_id))
report <- c("# Cleaning of Dutch train disruptions", "",
 sprintf("Source: `%s` (MD5: `%s`).", INPUT, unname(tools::md5sum(INPUT))),
 sprintf("From **%s** raw rows to **%s** selected disruptions. **%s** rows set aside.", n, nrow(clean), nrow(excluded)), "",
 "## Steps and counts", "",
 "| Step | Rule | Removed in this step | Remaining |", "|---|---|---:|---:|",
 vapply(seq_len(nrow(audit)), function(i) sprintf("| %s | %s | %s | %s |", i,
 audit$description[i], audit$removed_this_step[i], audit$remaining_rows[i]), character(1)), "",
 "A row can match several rules. The table counts each row once, at the first rule it matches. `excluded_disruptions.csv` keeps the original values, CSV row number, first reason, all reasons and any foreign names found.", "",
 "## Choices and limitations", "",
 "- This is a strict, reproducible analysis selection, not proof that every excluded record is wrong. The raw data are preserved; the clean CSV in data/ is rebuilt.",
 sprintf("- Maximum duration: %s minutes. Both the reported and the calculated duration must be within the limit. Long bridge damage, strikes and weather problems can be genuine incidents. This selection only predicts within the selected duration population; at onset you do not yet know whether a disruption will last longer than 24 hours. For deployment, also evaluate on all valid durations.", MAX_DURATION_MINUTES),
 sprintf("- A duration difference above %s minute leads to exclusion, not to an invented correction. This mainly removes early years and changes the population. See `yearly_retention.csv`, `yearly_profile.csv` and `threshold_sensitivity.csv`.", MAX_DIFFERENCE_MINUTES),
 "- Domestic means: all standardised route endpoints are on the explicit Dutch list, and no foreign name is found in the location fields. A mixed domestic/international record is excluded entirely. This is a deliberate, conservative scope; it does not prove that the actual disruption was across the border.",
 "- Missing or unknown standardised routes are set aside: the free NS text is not reliable enough to guarantee domestic endpoints automatically. Unknown future endpoints are never automatically treated as Dutch.",
 "- Test messages are recognised explicitly. Journey-planner problems, information messages and explanations are set aside, because they could otherwise be counted twice next to an original disruption. The exact patterns are in the script. Unrecognisable test messages cannot be guaranteed to be detected without further source information.",
 "- Missing station and cause data remain NA, with indicators. No stations or causes are invented. Only a missing cause_group becomes unknown. Removing all rows with NA would needlessly discard historical data.",
 "- Local source times are interpreted as Europe/Amsterdam. Non-existent and ambiguous daylight-saving moments are set aside for checking. Output timestamps are in UTC; month, weekday (Monday=1) and hour remain local.",
 "- `long_disruption` (duration_minutes > 60) is a helper column from the original binary plan; the final modelling target is 102 duration classes (see moddeling/01_target and docs/PROCESS.md, decision 2). The original statistical cause is kept for inspection but must not be a model predictor. End time and all duration fields are not predictors either. The last recorded cause may also contain information from after the start.",
 "- No automatic removal of genuine disruption groups such as engineering work, strikes or unknown causes. No IQR filter: that would remove exactly the long disruptions in the class we want to predict.", "",
 "## Run", "", "```sh", "Rscript \"Data Cleaning/clean_disruptions.R\"", "```", "",
 "Only base R is needed. Limits and lists are at the top of / in the script. The script checks totals, IDs, filters, target and the saved CSV. Outputs and data/disruptions_2011_2025_clean.csv are replaced when re-run; the raw source is not.", "",
 "Source definitions and limitations: https://www.rijdendetreinen.nl/open-data/treinstoringen",
 "Dataset attribution: Rijden de Treinen, CC BY 4.0. Cleaning script prepared with AI assistance.")
writeLines(report, file.path(OUTPUT, "cleaning_report.md"), useBytes = TRUE)
print(audit, row.names = FALSE)
cat("\nSaved", nrow(clean), "rows to", OUTPUT, "\n")
