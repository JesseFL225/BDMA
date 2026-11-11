# Shared data preparation. Source from the repository root; sourcing has no side effects.
# Base R only. No predictive models are fitted and no files are written here.

# Reuse ONLY the existing Step 01 function assignment, not its output-writing driver.
load_duration_assigner <- function(path, classes) {
  expressions <- parse(path)
  selected <- Filter(function(e) is.call(e) && identical(e[[1]], as.name("<-")) &&
    identical(e[[2]], as.name("assign_duration_class")), as.list(expressions))
  if (length(selected) != 1L) stop("Cannot uniquely locate Step 01 assignment function.")
  env <- new.env(parent = baseenv())
  eval(selected[[1]], envir = env)
  cutoff <- tail(classes$lower_inclusive_minutes, 1)
  fun <- env$assign_duration_class
  function(minutes) fun(minutes, cutoff_minutes = cutoff)
}

parse_utc <- function(x) as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
list_tokens <- function(x) lapply(x, function(s) {
  if (is.na(s) || !nzchar(trimws(s))) return(character())
  z <- unique(trimws(strsplit(s, ",", fixed = TRUE)[[1]]))
  z[nzchar(z)]
})

# Read outcome fields only for selected physical records. Fail closed if CSV
# records span lines, because skip/nrows would otherwise address the wrong rows.
read_selected_outcomes <- function(path, rows, header) {
  out <- data.frame(end_time = rep(NA_character_, length(rows)),
                    duration_minutes = rep(NA_real_, length(rows)))
  if (!length(rows)) return(out)
  cc <- setNames(rep("NULL", length(header)), header)
  cc[c("end_time", "duration_minutes")] <- "character"
  runs <- split(seq_along(rows), cumsum(c(TRUE, diff(rows) != 1L)))
  for (r in runs) {
    z <- read.csv(path, header = FALSE, col.names = header, skip = rows[r[1]],
      nrows = length(r), colClasses = cc, na.strings = c("", "NA"))
    if (nrow(z) != length(r)) stop("Outcome row alignment failed.")
    out$end_time[r] <- z$end_time
    out$duration_minutes[r] <- as.numeric(z$duration_minutes)
  }
  out
}

# Stateless feature engineering: learns nothing from validation or test.
engineer_features <- function(data, timezone = "Europe/Amsterdam", include_cause = FALSE) {
  t <- parse_utc(data$start_time)
  hour <- as.integer(format(t, "%H", tz = timezone))
  weekday <- as.integer(format(t, "%u", tz = timezone))
  month <- as.integer(format(t, "%m", tz = timezone))
  time <- data.frame(hour = hour, weekday = weekday, month = month,
    weekend = as.integer(weekday >= 6),
    rush_hour = as.integer(weekday <= 5 & ((hour >= 7 & hour < 9) | (hour >= 16 & hour < 19))))
  routes <- list_tokens(data$rdt_lines_id)
  stations <- list_tokens(toupper(data$rdt_station_codes))
  context <- time
  context$route_count <- ifelse(lengths(routes) == 0, NA_real_, lengths(routes))
  context$station_count <- ifelse(lengths(stations) == 0, NA_real_, lengths(stations))
  context$routes_missing <- as.integer(lengths(routes) == 0)
  context$stations_missing <- as.integer(lengths(stations) == 0)
  # Fixed, explicit domain choices; not selected using observed outcomes.
  hubs <- c(Amsterdam_Centraal = "ASD", Utrecht_Centraal = "UT",
            Rotterdam_Centraal = "RTD", Schiphol_Airport = "SHL", Den_Haag_Centraal = "GVC")
  for (hub in names(hubs)) context[[paste0("hub_", hub)]] <-
    vapply(stations, function(s) as.integer(hubs[[hub]] %in% s), integer(1))
  if (include_cause) {
    cause <- trimws(data$cause_group)
    context$cause_group <- ifelse(is.na(cause) | !nzchar(cause), "__MISSING__", cause)
    context$cause_missing <- as.integer(is.na(cause) | !nzchar(cause) |
      tolower(cause) == "unknown" | data$cause_missing %in% c("TRUE", "1"))
  }
  list(time_only = time, archived_context = context, routes = routes)
}

# Calendar levels are domain constants. Cause vocabulary and route vocabulary
# are learned from training only; each forward fold calls this function again.
fit_preprocessor <- function(features, rows, feature_set, top_n = 20L, scale_numeric = TRUE) {
  d <- features[[feature_set]][rows, , drop = FALSE]
  cat_levels <- list(hour = as.character(0:23), weekday = as.character(1:7), month = as.character(1:12))
  if ("cause_group" %in% names(d)) cat_levels$cause_group <-
    c(sort(setdiff(unique(d$cause_group), c("__MISSING__", "__UNSEEN__"))), "__MISSING__", "__UNSEEN__")
  numeric <- setdiff(names(d), names(cat_levels))
  medians <- vapply(d[numeric], function(x) if (all(is.na(x))) 0 else median(x, na.rm = TRUE), numeric(1))
  for (nm in numeric) d[[nm]][is.na(d[[nm]])] <- medians[[nm]]
  centers <- vapply(d[numeric], mean, numeric(1))
  scales <- vapply(d[numeric], sd, numeric(1))
  scales[!is.finite(scales) | scales == 0] <- 1
  if (!scale_numeric) { centers[] <- 0; scales[] <- 1 }
  frequency <- table(unlist(features$routes[rows], use.names = FALSE))
  ranking <- order(-as.numeric(frequency), names(frequency))
  top_routes <- if (feature_set == "archived_context") head(names(frequency)[ranking], top_n) else character()
  list(feature_set = feature_set, categorical_levels = cat_levels, numeric = numeric,
       medians = medians, centers = centers, scales = scales, top_routes = top_routes,
       fit_rows = rows, scale_numeric = scale_numeric)
}

apply_preprocessor <- function(features, rows, prep) {
  d <- features[[prep$feature_set]][rows, , drop = FALSE]
  x <- matrix(numeric(), nrow = length(rows), ncol = 0)
  for (nm in names(prep$categorical_levels)) {
    levels <- prep$categorical_levels[[nm]]
    values <- as.character(d[[nm]])
    values[is.na(values)] <- "__MISSING__"
    values[!values %in% levels] <- "__UNSEEN__"
    if (!all(values %in% levels)) stop("Invalid calendar category.")
    block <- outer(values, levels, "==") * 1
    colnames(block) <- paste(nm, make.names(levels, unique = TRUE), sep = "_")
    x <- cbind(x, block)
  }
  for (nm in prep$numeric) {
    v <- d[[nm]]
    v[is.na(v)] <- prep$medians[[nm]]
    block <- matrix((v - prep$centers[[nm]]) / prep$scales[[nm]], ncol = 1,
                    dimnames = list(NULL, nm))
    x <- cbind(x, block)
  }
  for (route in prep$top_routes) {
    block <- matrix(vapply(features$routes[rows], function(z) as.numeric(route %in% z), numeric(1)),
      ncol = 1, dimnames = list(NULL, paste0("route_", make.names(route))))
    x <- cbind(x, block)
  }
  storage.mode(x) <- "double"
  if (any(!is.finite(x)) || anyDuplicated(colnames(x))) stop("Invalid model matrix.")
  x
}

# Return both feature sets with a common ID/target contract.
# Test labels remain NA unless explicitly unlocked AFTER model selection.
# For tuning, change train_years/validation_years; preprocessing is refitted.
prepare_data <- function(data_path = "data/disruptions_2011_2025_clean.csv",
    classes_path = "moddeling/01_target/output/classes.csv",
    target_script = "moddeling/01_target/define_duration_classes.R",
    train_years = 2011:2023, validation_years = 2024L, test_years = 2025L,
    include_test_outcomes = FALSE, include_retrospective_cause = FALSE,
    scale_numeric = TRUE, expected_rows = 44248L) {
  if (!length(train_years) || !length(validation_years) || !length(test_years) ||
      max(train_years) >= min(validation_years) || max(validation_years) >= min(test_years))
    stop("Require nonempty chronological, nonoverlapping year sets.")
  if (any(c(train_years, validation_years) >= 2025)) stop("2025 cannot be used for model development.")
  header <- names(read.csv(data_path, nrows = 0))
  keep <- c("rdt_id", "start_time", "start_year", "source_year", "rdt_lines_id", "rdt_station_codes", "cause_group", "cause_missing")
  if (!all(c(keep, "end_time", "duration_minutes") %in% header)) stop("Required columns missing.")
  cc <- setNames(rep("NULL", length(header)), header)
  cc[keep] <- "character"
  data <- read.csv(data_path, colClasses = cc, na.strings = c("", "NA"))
  if (length(count.fields(data_path, sep = ",", quote = "\"", blank.lines.skip = FALSE)) != nrow(data) + 1L)
    stop("Multiline CSV records require a different selective-outcome reader.")
  if (!is.null(expected_rows) && nrow(data) != expected_rows) stop("Unexpected dataset row count.")
  if (anyNA(data$rdt_id) || anyDuplicated(data$rdt_id)) stop("Missing or duplicated disruption IDs.")
  start <- parse_utc(data$start_time)
  if (anyNA(start)) stop("Unparseable start times; no rows discarded.")
  year <- as.integer(format(start, "%Y", tz = "Europe/Amsterdam"))
  if (anyNA(data$start_year) || anyNA(data$source_year) ||
      any(year != as.integer(data$start_year) | year != as.integer(data$source_year))) stop("Year metadata mismatch.")
  split <- rep("outside_requested_years", nrow(data))
  split[year %in% train_years] <- "train"
  split[year %in% validation_years] <- "validation"
  split[year %in% test_years] <- "test"
  outcome_rows <- which(split %in% c("train", "validation") | (include_test_outcomes & split == "test"))
  outcomes <- read_selected_outcomes(data_path, outcome_rows, header)
  duration <- rep(NA_real_, nrow(data))
  end <- rep(as.POSIXct(NA, tz = "UTC"), nrow(data))
  duration[outcome_rows] <- outcomes$duration_minutes
  end[outcome_rows] <- parse_utc(outcomes$end_time)
  if (any(!is.finite(duration[outcome_rows]) | duration[outcome_rows] <= 0) ||
      anyNA(end[outcome_rows]) || any(end[outcome_rows] <= start[outcome_rows])) stop("Invalid development outcomes; no rows discarded.")
  boundary <- as.POSIXct(sprintf("%d-01-01 00:00:00", min(validation_years)), tz = "Europe/Amsterdam")
  boundary <- as.POSIXct(as.numeric(boundary), origin = "1970-01-01", tz = "UTC")
  purge <- which(split == "train" & end >= boundary)
  exclusions <- data.frame(rdt_id = data$rdt_id[purge], reason = rep("training_event_not_finished_before_validation", length(purge)))
  outside <- which(split == "outside_requested_years")
  exclusions <- rbind(exclusions, data.frame(rdt_id = data$rdt_id[outside], reason = rep("outside_requested_years", length(outside))))
  split[purge] <- "excluded_boundary"
  classes <- read.csv(classes_path, stringsAsFactors = FALSE)
  stopifnot(nrow(classes) == 102L, identical(classes$class_id, 0:101),
    identical(classes$lower_inclusive_minutes, seq(0L, 1010L, 10L)),
    all(head(classes$upper_exclusive_minutes, -1) == tail(classes$lower_inclusive_minutes, -1)),
    is.infinite(tail(classes$upper_exclusive_minutes, 1)), !anyDuplicated(classes$label))
  assign_class <- load_duration_assigner(target_script, classes)
  boundary_values <- c(9, 10, 19, 20, 1009, 1010, 1440)
  stopifnot(identical(assign_class(boundary_values), c(0L, 1L, 1L, 2L, 100L, 101L, 101L)))
  ids <- rep(NA_integer_, nrow(data))
  ids[outcome_rows] <- assign_class(duration[outcome_rows])
  y <- factor(classes$label[ids + 1L], levels = classes$label, ordered = TRUE)
  features <- engineer_features(data, include_cause = include_retrospective_cause)
  fit_rows <- which(split == "train")
  if (!length(fit_rows) || !any(split == "validation") || !any(split == "test")) stop("An intended split is empty.")
  preprocessors <- lapply(c("time_only", "archived_context"), function(s)
    fit_preprocessor(features, fit_rows, s, scale_numeric = scale_numeric))
  names(preprocessors) <- c("time_only", "archived_context")
  result <- lapply(c("train", "validation", "test"), function(s) {
    rows <- which(split == s)
    x <- lapply(preprocessors, function(p) apply_preprocessor(features, rows, p))
    list(ids = data$rdt_id[rows], X = x, y = y[rows], class_id = ids[rows],
      duration_minutes = duration[rows],
      metadata = data.frame(rdt_id = data$rdt_id[rows], split = s,
        start_time = data$start_time[rows], local_start_year = year[rows],
        outcome_available = !is.na(duration[rows]), stringsAsFactors = FALSE))
  })
  names(result) <- c("train", "validation", "test")
  for (s in names(result)) for (f in names(preprocessors))
    stopifnot(identical(colnames(result[[s]]$X[[f]]), colnames(result$train$X[[f]])))
  preprocessors <- lapply(preprocessors, function(p) {p$fit_ids <- data$rdt_id[p$fit_rows]; p})
  result$classes <- classes
  result$class_levels <- classes$label
  result$probability_columns <- paste0("p_", classes$label)
  result$preprocessing <- preprocessors
  result$exclusions <- exclusions
  result$audit <- list(input_rows = nrow(data), split_counts = table(factor(split,
    levels = c("train", "validation", "test", "excluded_boundary", "outside_requested_years"))),
    dataset_md5 = unname(tools::md5sum(data_path)), classes_md5 = unname(tools::md5sum(classes_path)),
    target_script_md5 = unname(tools::md5sum(target_script)),
    train_years = train_years, validation_years = validation_years, test_years = test_years,
    training_label_cutoff = format(boundary, tz = "UTC", usetz = TRUE),
    test_outcomes_unlocked = include_test_outcomes, retrospective_cause = include_retrospective_cause,
    retrospective_warning = "Archived route/station/cause fields may be revised after onset; not proven real-time predictors.",
    boundary_checks = data.frame(minutes = boundary_values, class_id = assign_class(boundary_values)),
    training_class_counts = tabulate(ids[fit_rows] + 1L, nbins = nrow(classes)),
    R_version = R.version.string)
  message("Prepared ", nrow(data), " rows; exclusions: ", nrow(exclusions),
          "; test outcomes unlocked: ", include_test_outcomes)
  result
}
