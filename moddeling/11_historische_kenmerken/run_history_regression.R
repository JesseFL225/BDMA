# Experiment 2: add history while retaining Step 10 model settings and cohorts.
source("moddeling/10_regressie_experiment/regression.R")
source("moddeling/11_historische_kenmerken/validate_history.R")
output <- "moddeling/11_historische_kenmerken/output"
dir.create(file.path(output, "models"), recursive = TRUE, showWarnings = FALSE)
protected <- c(list.files("data", full.names = TRUE, pattern = "csv$"),
 unlist(lapply(list.dirs("moddeling", recursive = FALSE)[grepl("^(0[1-9]|10)_", basename(list.dirs("moddeling", recursive = FALSE)))],
 function(p) list.files(p, recursive = TRUE, full.names = TRUE))))
before <- tools::md5sum(protected)
events <- read_development_history()
message("Building as-of history for ", nrow(events), " development records only")
history <- make_history_features(events)
stopifnot(all(history$checks[-1]))
write.csv(history$checks, file.path(output, "point_in_time_checks.csv"), row.names = FALSE)
con <- gzfile(file.path(output, "development_history_features.csv.gz"), "wt")
tryCatch(write.csv(cbind(rdt_id = history$ids, history$values), con, row.names = FALSE), finally = close(con))
classes <- read.csv("moddeling/01_target/output/classes.csv")
assigner <- load_duration_assigner("moddeling/01_target/define_duration_classes.R", classes)
settings <- read.csv("moddeling/10_regressie_experiment/output/selected_settings.csv")
grid <- read.csv("moddeling/10_regressie_experiment/output/candidate_grid.csv")
write.csv(merge(settings, grid, by = "candidate"), file.path(output, "fixed_settings_from_step10.csv"), row.names = FALSE)
fold_results <- data.frame()
for (year in c(2021L, 2022L)) {
 d <- prepare_data(train_years = 2011:year, validation_years = year + 1L,
   include_retrospective_cause = TRUE, include_test_outcomes = FALSE)
 for (f in c("time_only", "archived_context")) {
   message("History regression ", f, " fold ", year + 1L)
   x <- augment_history(d, history, f)
   setting <- grid[grid$candidate == settings$candidate[settings$feature_set == f], ]
   fit <- fit_duration_regression(x$train, d$train$duration_minutes, setting)
   p <- predict_duration_regression(fit, x$validation)
   score <- regression_metrics(d$validation$duration_minutes, p, assigner)
   old <- read.csv("moddeling/10_regressie_experiment/output/tuning_folds.csv")
   old <- old[old$feature_set == f & old$candidate == setting$candidate & old$validation_year == year + 1L, ]
   stopifnot(nrow(old) == 1L, old$n == length(p), all(is.na(d$test$duration_minutes)))
   fold_results <- rbind(fold_results, data.frame(feature_set = f, validation_year = year + 1L,
     n = length(p), old_mae_minutes = old$mae_minutes, history_mae_minutes = score$mae_minutes))
   rm(fit); gc(FALSE)
 }
}
write.csv(fold_results, file.path(output, "forward_fold_comparison.csv"), row.names = FALSE)
# The fold comparison is descriptive: there is no new grid selection or tuning.
d <- prepare_data(include_retrospective_cause = TRUE, include_test_outcomes = FALSE)
stopifnot(all(is.na(d$test$duration_minutes)))
old <- read.csv("moddeling/10_regressie_experiment/output/validation_predictions.csv.gz")
stopifnot(identical(as.character(old$rdt_id), d$validation$ids),
 identical(as.numeric(old$true_minutes), as.numeric(d$validation$duration_minutes)))
provenance <- readLines("moddeling/10_regressie_experiment/output/verification_report.md")
stopifnot(paste("Dataset MD5:", d$audit$dataset_md5) %in% provenance)
predictions <- data.frame(rdt_id = d$validation$ids, split = "validation", true_minutes = d$validation$duration_minutes)
results <- data.frame()
imputation <- data.frame()
checks <- data.frame(check = c("Synthetic history edge cases", "All development rows strictly as-of",
 "2025 outcomes unavailable", "Step 10 dataset/cohort/truth match"), passed = TRUE)
for (f in c("time_only", "archived_context")) {
 message("Final history regression ", f)
 x <- augment_history(d, history, f)
 setting <- grid[grid$candidate == settings$candidate[settings$feature_set == f], ]
 fit <- fit_duration_regression(x$train, d$train$duration_minutes, setting)
 fit$history_imputation <- x$imputation
 fit$history_columns <- x$columns
 fit$dataset_md5 <- d$audit$dataset_md5
 fit$fit_ids <- d$train$ids
 p <- predict_duration_regression(fit, x$validation)
 predictions[[paste0(f, "_original")]] <- old[[f]]
 predictions[[paste0(f, "_history")]] <- p
 for (variant in c("original", "history")) {
   results <- rbind(results, data.frame(feature_set = f, variant = variant,
     regression_metrics(d$validation$duration_minutes, predictions[[paste0(f, "_", variant)]], assigner)))
 }
 imputation <- rbind(imputation, data.frame(feature_set = f, feature = names(x$imputation), training_median = x$imputation))
 model_path <- file.path(output, "models", paste0(f, ".rds"))
 saveRDS(fit, model_path)
 stopifnot(isTRUE(all.equal(p[1:20], predict_duration_regression(readRDS(model_path), x$validation[1:20, , drop = FALSE]), tolerance = 1e-10)))
 checks <- rbind(checks, data.frame(check = paste(f, "serialized predictions match"), passed = TRUE))
}
write.csv(imputation, file.path(output, "training_only_imputation.csv"), row.names = FALSE)
write.csv(results, file.path(output, "validation_comparison.csv"), row.names = FALSE)
con <- gzfile(file.path(output, "validation_predictions.csv.gz"), "wt")
tryCatch(write.csv(predictions, con, row.names = FALSE), finally = close(con))
restored <- read.csv(file.path(output, "validation_predictions.csv.gz"))
for (f in c("time_only", "archived_context")) {
 e <- regression_metrics(restored$true_minutes, restored[[paste0(f, "_history")]], assigner)
 stopifnot(isTRUE(all.equal(e, results[results$feature_set == f & results$variant == "history", -(1:2)], check.attributes = FALSE, tolerance = 1e-10)))
}
dates <- format(parse_utc(d$validation$metadata$start_time), "%Y-%m-%d", tz = "Europe/Amsterdam")
bootstrap <- do.call(rbind, lapply(c("time_only", "archived_context"), function(f) {
 delta <- abs(predictions[[paste0(f, "_history")]] - predictions$true_minutes) -
   abs(predictions[[paste0(f, "_original")]] - predictions$true_minutes)
 totals <- tapply(delta, dates, sum); counts <- table(factor(dates, levels = names(totals)))
 set.seed(42)
 boot <- replicate(500, {i <- sample.int(length(totals), length(totals), replace = TRUE); sum(totals[i])/sum(counts[i])})
 data.frame(feature_set = f, history_minus_original_mae = mean(delta),
   lower_95 = unname(quantile(boot, .025)), upper_95 = unname(quantile(boot, .975)))
}))
write.csv(bootstrap, file.path(output, "paired_day_bootstrap.csv"), row.names = FALSE)
stopifnot(identical(before, tools::md5sum(protected)))
checks <- rbind(checks, data.frame(check = c("Saved CSV reproduces metrics", "Data and Steps 01–10 unchanged"), passed = TRUE))
write.csv(checks, file.path(output, "validation_checks.csv"), row.names = FALSE)
writeLines(c("# History regression verification", "",
 paste("Development events with as-of feature checks:", nrow(events)),
 paste("Dataset MD5:", d$audit$dataset_md5), "No 2025 outcomes loaded. No retrospective access to unfinished outcomes.",
 "Current and equal-time events excluded. Multi-route historical events deduplicated.",
 "Fixed windows and Step 10 settings, no new tuning. Imputation fits training only.",
 "Sequential validation protocol: earlier validation outcomes enter history only once their event ended.",
 "Original archive membership and route/cause revisions are NOT reconstructed as they were at onset.",
 "", capture.output(sessionInfo())), file.path(output, "verification_report.md"))
table <- data.frame(Features = results$feature_set, Variant = results$variant,
 MAE_minutes = round(results$mae_minutes, 2), Within_10_pct = round(results$within_10_pct, 2),
 Within_20_pct = round(results$within_20_pct, 2), Exact_class_pct = round(results$exact_class_pct, 2))
md <- c(paste0("| ", paste(names(table), collapse = " | "), " |"), "|---|---|---:|---:|---:|---:|",
 apply(table, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
writeLines(c("# Step 11 — Experiment 2: historical features", "",
 "Owner: Oliver. Status: implemented and evaluated on 2024. Development experiment before the locked Step 09 final test.", "",
 "## Goal and method", "",
 "Measure whether historical information improves Step 10 absolute-error regression. Same clean dataset, feature preprocessing, cohorts and previously selected model settings. No external data, new cleaning, new tuning or test evaluation.", "",
 "## Added features", "",
 "Both feature sets add network-wide prior-start counts (24 hours and 7 days), number and median duration of globally completed events (90 days), and a missing-history indicator. Counts refer to events retained in this selected archive, not all real-world disruptions.",
 "Archived context additionally adds counts of earlier events sharing any route (7/30 days), number and median duration of completed events sharing a route (90 days), and number/median duration of completed events in the same archived cause group (90 days). Events sharing multiple routes count once. Median features have missingness indicators and training-fitted imputation; count zero is a real zero.", "",
 "## Chronology and assumptions", "",
 "Previous starts must be strictly earlier than the current start. Duration features use only events whose recorded end precedes the current start; the 90-day window uses completion time. Equal-time and current events are excluded. Global/route/cause historical outcomes are not accessible while those events are running.",
 "Earlier validation events may update history after completion; models remain fixed. This simulates sequential prediction during 2024, not a batch forecast made on 1 January. The same rule applies in the earlier folds. No 2025 outcomes are loaded.",
 "Important limitation: we use the final, outcome-filtered clean archive. Its membership is not knowable at onset, and route/cause fields may have been revised. Start counts are therefore retrospective counts of eligible events, not validated real-time load measures. Even strict temporal indexing does not remove this selection/availability issue. The actual delay between an end event and its publication is unknown. These are historical proof-of-concept results within the selected population.", "",
 "## Results", "", md, "",
 "Lower MAE is better; tolerances include their boundaries. Exact-class accuracy uses the unchanged 102-class definition. Descriptive paired calendar-day bootstrap intervals are in output/paired_day_bootstrap.csv; negative differences favour history. Forward-fold results provide an earlier-year check, not an independent test: their settings were previously selected using those years.", "",
 "## Project impact", "",
 "Observed result: history does not improve MAE in either feature set on 2024. Context MAE rises from 68.06 to 68.95 minutes, while within-20-minute coverage rises from 36.67% to 37.25%. Both descriptive bootstrap intervals for MAE differences include zero. Retain Step 10 as the MAE reference; the small tolerance gains do not establish an overall improvement.", "",
 "This experiment isolates one feature block while keeping model settings fixed. Retain or reject history based on the measured trade-offs, not a promise that more columns always help. Repeated work on 2024 can overfit validation; 2025 must remain reserved. This step does not automatically replace the original model or start an external-data experiment.", "",
 "## Run and outputs", "", "```sh", "Rscript moddeling/11_historische_kenmerken/run_history_regression.R", "```", "",
 "Uses the existing local xgboost installation and Step 10 saved predictions/settings. history_features.R builds history; validate_history.R checks simultaneous events, uncompleted outcomes, multi-route deduplication, empty history, future-label perturbations and row-order invariance. Outputs contain development features, per-row chronology checks, imputation, fold comparisons, predictions, metrics and verification. Model caches are Git-ignored.", "",
 "## Handoff and change log", "",
 "Review results against Step 10 before deciding on retuning, new data or final model selection. Original data and Steps 01–10 remain unchanged. Implemented with AI assistance; no commits, pushes or test unlocking performed by these scripts."),
 "moddeling/11_historische_kenmerken/README.md")
print(results); print(fold_results); print(bootstrap)
