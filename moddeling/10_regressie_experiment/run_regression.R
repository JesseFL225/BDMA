# Run from BDMA root. This development experiment precedes the locked Step 09 test.
source("moddeling/10_regressie_experiment/regression.R")
set.seed(42)
output <- "moddeling/10_regressie_experiment/output"
dir.create(file.path(output, "models"), recursive = TRUE, showWarnings = FALSE)
protected <- c(list.files("data", full.names = TRUE, pattern = "csv$"),
  unlist(lapply(sprintf("%02d", 1:9), function(prefix) {
    folders <- list.dirs("moddeling", recursive = FALSE)
    folder <- folders[startsWith(basename(folders), prefix)]
    unlist(lapply(folder, list.files, recursive = TRUE, full.names = TRUE))
  })))
before <- tools::md5sum(protected)
classes <- read.csv("moddeling/01_target/output/classes.csv")
assigner <- load_duration_assigner("moddeling/01_target/define_duration_classes.R", classes)
fixture <- regression_metrics(c(5, 10, 30), c(15, 30, 20), assigner)
stopifnot(abs(fixture$mae_minutes - 40/3) < 1e-10,
  abs(fixture$within_10_pct - 200/3) < 1e-10, fixture$within_20_pct == 100,
  fixture$exact_class_pct == 0)
grid <- data.frame(candidate = c("depth2_round100", "depth4_round100", "depth2_round300"),
  max_depth = c(2L, 4L, 2L), nrounds = c(100L, 100L, 300L))
write.csv(grid, file.path(output, "candidate_grid.csv"), row.names = FALSE)
features <- c("time_only", "archived_context")
tuning <- data.frame()
for (year in c(2021L, 2022L)) {
  d <- prepare_data(train_years = 2011:year, validation_years = year + 1L,
    include_retrospective_cause = TRUE, include_test_outcomes = FALSE)
  stopifnot(all(is.na(d$test$duration_minutes)))
  for (f in features) for (i in seq_len(nrow(grid))) {
    message("Regression ", f, " fold ", year + 1L, " ", grid$candidate[i])
    model <- fit_duration_regression(d$train$X[[f]], d$train$duration_minutes, grid[i, ])
    pred <- predict_duration_regression(model, d$validation$X[[f]])
    score <- regression_metrics(d$validation$duration_minutes, pred, assigner)
    base <- regression_metrics(d$validation$duration_minutes,
      rep(median(d$train$duration_minutes), length(pred)), assigner)
    tuning <- rbind(tuning, data.frame(feature_set = f, candidate = grid$candidate[i],
      validation_year = year + 1L, train_n = length(d$train$ids), n = length(pred),
      mae_minutes = score$mae_minutes, baseline_mae_minutes = base$mae_minutes,
      training_only_preprocessing = identical(d$preprocessing[[f]]$fit_ids, d$train$ids)))
    rm(model); gc(FALSE)
  }
}
stopifnot(all(tuning$training_only_preprocessing), all(tuning$validation_year < 2024))
write.csv(tuning, file.path(output, "tuning_folds.csv"), row.names = FALSE)
summary <- aggregate(mae_minutes ~ feature_set + candidate, tuning, mean)
selected <- do.call(rbind, lapply(features, function(f) {
  z <- summary[summary$feature_set == f, ]
  z[order(z$mae_minutes, match(z$candidate, grid$candidate)), ][1, ]
}))
write.csv(summary, file.path(output, "tuning_summary.csv"), row.names = FALSE)
write.csv(selected, file.path(output, "selected_settings.csv"), row.names = FALSE)
# Settings frozen before 2024 scoring. No extra features or different eligibility.
d <- prepare_data(include_retrospective_cause = TRUE, include_test_outcomes = FALSE)
stopifnot(all(is.na(d$test$duration_minutes)), all(is.na(d$test$y)))
median_minutes <- median(d$train$duration_minutes)
baseline_prediction <- rep(median_minutes, length(d$validation$ids))
results <- data.frame(model = "training_median", feature_set = "none",
  regression_metrics(d$validation$duration_minutes, baseline_prediction, assigner))
predictions <- data.frame(rdt_id = d$validation$ids, split = "validation",
  true_minutes = d$validation$duration_minutes, training_median = baseline_prediction)
checks <- data.frame(check = c("Hand-calculated metric fixture", "2025 outcomes locked"), passed = TRUE)
for (f in features) {
  setting <- grid[grid$candidate == selected$candidate[selected$feature_set == f], ]
  model <- fit_duration_regression(d$train$X[[f]], d$train$duration_minutes, setting)
  model$dataset_md5 <- d$audit$dataset_md5
  model$fit_ids <- d$train$ids
  pred <- predict_duration_regression(model, d$validation$X[[f]])
  results <- rbind(results, data.frame(model = "xgboost_absolute_error", feature_set = f,
    regression_metrics(d$validation$duration_minutes, pred, assigner)))
  predictions[[f]] <- pred
  path <- file.path(output, "models", paste0(f, ".rds"))
  saveRDS(model, path)
  reproduced <- predict_duration_regression(readRDS(path), d$validation$X[[f]][1:20, , drop = FALSE])
  stopifnot(isTRUE(all.equal(pred[1:20], reproduced, tolerance = 1e-10)))
  checks <- rbind(checks, data.frame(check = paste(f, "saved model reproduces predictions"), passed = TRUE))
}
con <- gzfile(file.path(output, "validation_predictions.csv.gz"), "wt")
tryCatch(write.csv(predictions, con, row.names = FALSE), finally = close(con))
restored <- read.csv(file.path(output, "validation_predictions.csv.gz"))
stopifnot(identical(as.character(restored$rdt_id), d$validation$ids))
for (f in features) stopifnot(isTRUE(all.equal(
  regression_metrics(restored$true_minutes, restored[[f]], assigner),
  results[results$feature_set == f, -(1:2)], tolerance = 1e-10, check.attributes = FALSE)))
results$mae_reduction_vs_baseline_pct <- 100 * (1 - results$mae_minutes / results$mae_minutes[1])
write.csv(results, file.path(output, "validation_comparison.csv"), row.names = FALSE)

# Descriptive paired day bootstrap; this is not independent final-test evidence.
dates <- format(parse_utc(d$validation$metadata$start_time), "%Y-%m-%d", tz = "Europe/Amsterdam")
bootstrap <- do.call(rbind, lapply(features, function(f) {
  delta <- abs(predictions[[f]] - predictions$true_minutes) - abs(baseline_prediction - predictions$true_minutes)
  totals <- tapply(delta, dates, sum); counts <- table(factor(dates, levels = names(totals)))
  set.seed(42)
  samples <- replicate(500, {
    i <- sample.int(length(totals), length(totals), replace = TRUE)
    sum(totals[i]) / sum(counts[i])
  })
  data.frame(feature_set = f, mae_difference_minutes = mean(delta),
    lower_95 = unname(quantile(samples, .025)), upper_95 = unname(quantile(samples, .975)))
}))
write.csv(bootstrap, file.path(output, "paired_day_bootstrap.csv"), row.names = FALSE)
stopifnot(identical(before, tools::md5sum(protected)))
checks <- rbind(checks, data.frame(check = c("Saved predictions reproduce metrics",
  "Data and Steps 01–09 unchanged"), passed = TRUE))
write.csv(checks, file.path(output, "validation_checks.csv"), row.names = FALSE)
writeLines(c("# Regression experiment verification", "", paste("Training rows:", length(d$train$ids)),
  paste("Validation rows:", length(d$validation$ids)), paste("Training median minutes:", median_minutes),
  paste("Dataset MD5:", d$audit$dataset_md5), "Seed 42. Chronological tuning on 2022 and 2023 only.",
  "Same features and eligible rows as classification. No historical/external features added.",
  "2025 outcomes locked. Previous source files/results unchanged.", "", capture.output(sessionInfo())),
  file.path(output, "verification_report.md"))

table <- data.frame(Model = c("Median baseline", "Boosting: time", "Boosting: context"),
  MAE_minutes = round(results$mae_minutes, 2), Within_10_pct = round(results$within_10_pct, 2),
  Within_20_pct = round(results$within_20_pct, 2), Exact_class_pct = round(results$exact_class_pct, 2))
markdown <- c(paste0("| ", paste(names(table), collapse = " | "), " |"),
  "|---|---:|---:|---:|---:|", apply(table, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
writeLines(c("# Step 10 — Experiment 1: regression with existing features", "",
 "Owner: Oliver. Status: executed on training/validation only. This development experiment runs BEFORE the locked Step 09 final test, despite its folder number.", "",
 "## Question", "", "Does learning duration directly help, without adding data or changing cohort eligibility?", "",
 "## Method and input", "",
 "The unchanged shared preparation provides 2011–2023 training, 2024 validation and locked 2025 outcomes. Both existing feature sets are used, with retrospective cause explicitly enabled for archived_context. No history features, external sources or new cleaning.",
 "XGBoost reg:absoluteerror directly minimises L1 loss in minutes, targeting a conditional median. A constant training median is the baseline. Three candidates (depth 2/4, rounds 100/300, eta 0.05) are selected by equal-year average MAE on forward validation folds 2022 and 2023. No 2024 early stopping or further tuning. Predictions are clamped at zero, not rounded or capped at 1440.",
 "Other fixed settings: min_child_weight=10, subsample=0.8, colsample_bytree=0.8, lambda=1, two threads, seed 42. Initial prediction is the fold training median.",
 sprintf("Final training median: %.1f minutes.", median_minutes), "",
 "## Validation results", "", markdown, "",
 "MAE is mean absolute minute error (lower better). Within ±10/±20 includes the boundary. Exact-class accuracy uses the original 102-class definition, including >=1010, and is not interchangeable with a minute-error tolerance. Log loss from classifiers and minute MAE are different units and cannot be compared numerically.",
 "", "## Impact and limitations", "",
 sprintf("Archived-context regression changes MAE by %.2f%% relative to the global median baseline. This does not prove that new information is unnecessary or that the same gain holds on 2025.", results$mae_reduction_vs_baseline_pct[3]),
 "Point regression does not produce class probabilities or prediction intervals. Those are separate future experiments. The objective changed from classification log loss to absolute error, so improved MAE need not mean improved exact-bin accuracy. Archived inputs may be revised after onset; only time-only results avoid that specific retrospective-context issue.",
 "The previous 24-hour filter and historical exclusions still restrict generalisation. Paired calendar-day bootstrap intervals are descriptive validation uncertainty; repeated development against 2024 can overfit that year. Keep 2025 untouched.",
 "", "## Files and checks", "",
 "regression.R defines model/metrics; run_regression.R executes this experiment. output/ contains the grid, fold results, selected settings, validation predictions and metrics, day-bootstrap intervals, and verification. Model caches are local and Git-ignored. Checks cover manual error calculations/boundaries, serialization, CSV round-trip, test locking and protected-file hashes.",
 "", "## Run", "", "```sh", "Rscript moddeling/10_regressie_experiment/run_regression.R", "```", "",
 "Requires the already installed xgboost package (optional setup: Rscript moddeling/05_random_forest/install_dependencies.R). Run from the BDMA root.",
 "", "## Next step", "", "Review these results before adding historical features. Keep this run as the fixed existing-feature comparator. Do not start the final test or replace the original classifiers automatically.",
 "", "## Change log and source", "", "Implemented and executed experiment 1 with AI assistance. Original data and previous modelling outputs preserved.",
 "https://xgboost.readthedocs.io/en/stable/parameter.html"), "moddeling/10_regressie_experiment/README.md")
print(results); print(bootstrap)
