# Validation-only comparison and error analysis. No test labels are unlocked.
# Run after Steps 05 and 06 from the BDMA root.
source("moddeling/05_random_forest/tree_workflow.R")
source("moddeling/05_random_forest/random_forest.R")
source("moddeling/06_gradient_boosting/gradient_boosting.R")
set.seed(42)
protected <- protected_modelling_files(); before <- tools::md5sum(protected)
output <- "moddeling/08_foutanalyse/output"
dir.create(output, recursive = TRUE, showWarnings = FALSE)
prepared <- prepare_data(include_retrospective_cause = TRUE, include_test_outcomes = FALSE)
stopifnot(all(is.na(prepared$test$y)), all(is.na(prepared$test$duration_minutes)))
sources <- data.frame(key = c("global", "cause", "logistic_time", "logistic_context",
 "forest_time", "forest_context", "boosting_time", "boosting_context"),
 path = c("03_baselines/output/global", "03_baselines/output/cause",
 "04_logistic_regression/output/time_only", "04_logistic_regression/output/archived_context",
 "05_random_forest/output/time_only", "05_random_forest/output/archived_context",
 "06_gradient_boosting/output/time_only", "06_gradient_boosting/output/archived_context"))
evaluations <- list()
for (i in seq_len(nrow(sources))) {
  p <- read.csv(paste0("moddeling/", sources$path[i], "_validation_predictions.csv.gz"), check.names = FALSE)
  evaluations[[sources$key[i]]] <- evaluate_predictions(p, expected_ids = prepared$validation$ids,
    expected_true_class = prepared$validation$y)
}
comparison <- do.call(rbind, lapply(names(evaluations), function(k) cbind(key = k, evaluations[[k]]$summary)))
rownames(comparison) <- NULL
comparison <- comparison[order(comparison$feature_set, comparison$log_loss), ]
write.csv(comparison, file.path(output, "validation_comparison.csv"), row.names = FALSE)

# Read metadata only. Target values/2025 outcomes are never loaded by this step.
path <- "data/disruptions_2011_2025_clean.csv"
header <- names(read.csv(path, nrows = 0))
cc <- setNames(rep("NULL", length(header)), header)
cc[c("rdt_id", "start_time", "cause_group", "rdt_lines_id")] <- "character"
metadata <- read.csv(path, colClasses = cc, na.strings = c("", "NA"))
metadata <- metadata[match(prepared$validation$ids, metadata$rdt_id), ]
stopifnot(identical(metadata$rdt_id, prepared$validation$ids))
t <- parse_utc(metadata$start_time)
month <- as.integer(format(t, "%m", tz = "Europe/Amsterdam"))
hour <- as.integer(format(t, "%H", tz = "Europe/Amsterdam"))
weekday <- as.integer(format(t, "%u", tz = "Europe/Amsterdam"))
metadata$date <- as.character(as.Date(format(t, "%Y-%m-%d", tz = "Europe/Amsterdam")))
metadata$month <- sprintf("%02d", month)
metadata$season <- c("winter", "winter", "spring", "spring", "spring", "summer",
 "summer", "summer", "autumn", "autumn", "autumn", "winter")[month]
metadata$rush_hour <- ifelse(weekday <= 5 & ((hour >= 7 & hour < 9) | (hour >= 16 & hour < 19)), "rush", "off_peak")
metadata$cause_group[is.na(metadata$cause_group)] <- "unknown"
routes <- list_tokens(metadata$rdt_lines_id)
group_metrics <- function(e, mask, type, value) {
  z <- e$per_observation[mask, ]
  data.frame(model = e$summary$model, feature_set = e$summary$feature_set,
    group_type = type, group = value, n = nrow(z), exact_count = sum(z$direction == "exact"),
    under_count = sum(z$direction == "under"), over_count = sum(z$direction == "over"),
    accuracy = mean(z$direction == "exact"), under_rate = mean(z$direction == "under"),
    over_rate = mean(z$direction == "over"), within_one_class_pct = 100 * mean(z$within_one_class),
    log_loss = mean(z$log_loss), small_group = nrow(z) < 50L)
}
subgroups <- data.frame()
for (key in names(evaluations)) {
  e <- evaluations[[key]]
  for (type in c("cause_group", "month", "season", "rush_hour")) {
    for (value in sort(unique(metadata[[type]])))
      subgroups <- rbind(subgroups, group_metrics(e, metadata[[type]] == value, type, value))
  }
  # Lines fixed by training frequency, never by validation errors.
  for (value in prepared$preprocessing$archived_context$top_routes) {
    mask <- vapply(routes, function(x) value %in% x, logical(1))
    if (any(mask)) subgroups <- rbind(subgroups, group_metrics(e, mask, "route_id", value))
  }
}
write.csv(subgroups, file.path(output, "subgroup_errors.csv"), row.names = FALSE)
classes <- do.call(rbind, lapply(names(evaluations), function(k) {
  e <- evaluations[[k]]
  cbind(model = e$summary$model, feature_set = e$summary$feature_set, e$per_class)
}))
write.csv(classes, file.path(output, "errors_per_class.csv"), row.names = FALSE)
ordinal <- do.call(rbind, lapply(names(evaluations), function(k) {
  e <- evaluations[[k]]
  cbind(model = e$summary$model, feature_set = e$summary$feature_set, e$ordinal_summary)
}))
write.csv(ordinal, file.path(output, "ordinal_comparison.csv"), row.names = FALSE)

# Paired resampling of calendar days, not independent disruption rows.
# This describes validation uncertainty after selection, not an unbiased test CI.
bootstrap <- data.frame()
selected <- do.call(rbind, lapply(c("time_only", "archived_context"), function(f) {
  z <- comparison[comparison$feature_set == f, ]
  z[which.min(z$log_loss), ]
}))
for (i in seq_len(nrow(selected))) {
  win <- selected[i, ]
  for (other in comparison$key[comparison$feature_set == win$feature_set & comparison$key != win$key]) {
    delta <- evaluations[[win$key]]$per_observation$log_loss - evaluations[[other]]$per_observation$log_loss
    day_sums <- tapply(delta, metadata$date, sum)
    day_n <- table(factor(metadata$date, levels = names(day_sums)))
    set.seed(42)
    boot <- replicate(500, {
      idx <- sample.int(length(day_sums), length(day_sums), replace = TRUE)
      sum(day_sums[idx]) / sum(day_n[idx])
    })
    bootstrap <- rbind(bootstrap, data.frame(feature_set = win$feature_set, selected = win$key,
      comparator = other, log_loss_difference = mean(delta),
      lower_95 = unname(quantile(boot, .025)), upper_95 = unname(quantile(boot, .975)),
      days = length(day_sums), replicates = 500L))
  }
}
write.csv(selected, file.path(output, "validation_selection_proposal.csv"), row.names = FALSE)
write.csv(bootstrap, file.path(output, "paired_day_bootstrap.csv"), row.names = FALSE)

# Grouped permutation importance for the strongest Oliver tree in each feature set.
# All columns of a logical group move together, preserving one-hot consistency.
# Fixed sample chosen by row index RNG, not by error/outcome values.
importance <- data.frame()
for (f in c("time_only", "archived_context")) {
  choices <- comparison[comparison$feature_set == f & grepl("forest|boosting", comparison$key), ]
  best <- choices[which.min(choices$log_loss), ]
  is_forest <- grepl("forest", best$key)
  folder <- if (is_forest) "05_random_forest" else "06_gradient_boosting"
  predict_fun <- if (is_forest) predict_forest else predict_boosting
  model <- readRDS(file.path("moddeling", folder, "output", "models", paste0(f, ".rds")))
  stopifnot(identical(model$dataset_md5, prepared$audit$dataset_md5),
    identical(model$classes_md5, prepared$audit$classes_md5), identical(model$fit_ids, prepared$train$ids))
  set.seed(42); rows <- sort(sample.int(length(prepared$validation$ids), min(2000L, length(prepared$validation$ids))))
  x <- prepared$validation$X[[f]][rows, , drop = FALSE]
  truth <- prepared$validation$class_id[rows] + 1L
  loss <- function(p) mean(-log(p[cbind(seq_len(nrow(p)), truth)]))
  baseline <- loss(predict_fun(model, x))
  cn <- colnames(x)
  groups <- list(time_of_week = which(grepl("^hour_|^weekday_|^weekend$|^rush_hour$", cn)),
    month = which(grepl("^month_", cn)),
    route_station_context = which(grepl("^route_|^routes_|^station_|^stations_|^hub_", cn)),
    cause = which(grepl("^cause_group_|^cause_missing$", cn)))
  groups <- groups[lengths(groups) > 0]
  stopifnot(setequal(unlist(groups), seq_len(ncol(x))))
  for (group in names(groups)) for (repeat_id in 1:3) {
    set.seed(42 + repeat_id)
    changed <- x; shuffled <- sample.int(nrow(x))
    changed[, groups[[group]]] <- x[shuffled, groups[[group]], drop = FALSE]
    score <- loss(predict_fun(model, changed))
    importance <- rbind(importance, data.frame(model = best$model, feature_set = f,
      group = group, repeat_id = repeat_id, n = nrow(x), baseline_log_loss = baseline,
      permuted_log_loss = score, log_loss_increase = score - baseline))
  }
  rm(model); gc(FALSE)
}
write.csv(importance, file.path(output, "grouped_permutation_importance.csv"), row.names = FALSE)
imp_summary <- aggregate(log_loss_increase ~ model + feature_set + group, importance,
  function(v) c(mean = mean(v), sd = sd(v)))
imp_summary <- cbind(imp_summary[1:3], as.data.frame(imp_summary$log_loss_increase))
names(imp_summary)[4:5] <- c("mean_log_loss_increase", "sd_log_loss_increase")
write.csv(imp_summary, file.path(output, "permutation_summary.csv"), row.names = FALSE)

source("moddeling/08_foutanalyse/plot_results.R")
e <- evaluations[[winner$key]]
write.csv(e$per_observation[order(-e$per_observation$log_loss), ][1:20, ],
 file.path(output, "largest_validation_losses.csv"), row.names = FALSE)
stopifnot(identical(before, tools::md5sum(protected)))
writeLines(c("# Error-analysis verification", "",
 "All eight prediction files passed the unchanged shared evaluator with identical validation IDs and labels.",
 "2025 labels remain locked. No test model selection or test evaluation performed.",
 "Metadata-only CSV import; source data and Mart-owned steps unchanged.",
 "Subgroup route memberships overlap. Groups under 50 are flagged; no small-group ranking claims.",
 "Paired bootstrap: 500 resamples of observed calendar days, descriptive validation intervals after selection.",
 "Grouped permutation: fixed random 2000-row validation subset, three repeats; no causal interpretation.",
 "Open-ended class is evaluated separately; class offsets are not minute errors.", "",
 paste("Dataset MD5:", prepared$audit$dataset_md5), capture.output(sessionInfo())),
 file.path(output, "verification_report.md"))
print(comparison); print(bootstrap); print(imp_summary)
