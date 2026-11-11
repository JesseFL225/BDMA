# Run from root: Rscript moddeling/02_voorbereiding/validate_preparation.R
# Preparation tests only: no predictive model fitting and no test outcomes.
source("moddeling/02_voorbereiding/prepare_data.R")
output <- "moddeling/02_voorbereiding/output"
dir.create(output, recursive = TRUE, showWarnings = FALSE)
protected <- c("data/disruptions_2011_2025_clean.csv",
  list.files("moddeling/01_target", recursive = TRUE, full.names = TRUE))
before <- tools::md5sum(protected)
checks <- character()
check <- function(condition, description) {
  if (!isTRUE(condition)) stop(description)
  checks <<- c(checks, description)
}
p <- prepare_data()
check(identical(as.integer(p$audit$split_counts), c(33004L, 5296L, 5948L, 0L, 0L)), "Expected real-data row counts; no exclusions")
all_ids <- unlist(lapply(p[c("train", "validation", "test")], `[[`, "ids"), use.names = FALSE)
check(length(all_ids) == 44248 && !anyNA(all_ids) && !anyDuplicated(all_ids), "Complete, unique, nonoverlapping IDs")
check(all(p$train$metadata$local_start_year %in% 2011:2023) &&
  all(p$validation$metadata$local_start_year == 2024) && all(p$test$metadata$local_start_year == 2025), "Chronological local-date split")
check(all(is.na(p$test$y)) && all(is.na(p$test$duration_minutes)) &&
  all(is.na(p$test$class_id)) && !any(p$test$metadata$outcome_available), "Test outcomes locked")
for (s in c("train", "validation", "test")) {
  check(is.ordered(p[[s]]$y) && identical(levels(p[[s]]$y), p$class_levels), paste(s, "fixed ordered target levels"))
  if (s != "test") check(!anyNA(p[[s]]$y), paste(s, "complete target labels"))
  for (f in names(p$preprocessing)) {
    x <- p[[s]]$X[[f]]
    check(nrow(x) == length(p[[s]]$ids) && all(is.finite(x)) &&
      identical(colnames(x), colnames(p$train$X[[f]])), paste(s, f, "aligned finite matrix and column order"))
  }
}
for (f in names(p$preprocessing)) {
  check(identical(p$preprocessing[[f]]$fit_ids, p$train$ids), paste(f, "preprocessing fitted only on training IDs"))
  check(!any(grepl("rdt_id|end_time|duration|calculated|difference|statistical|long_disruption", colnames(p$train$X[[f]]))), paste(f, "no forbidden predictor names"))
}
check(!any(grepl("cause", colnames(p$train$X$archived_context))), "Cause omitted unless explicitly requested")
check(identical(p$audit$boundary_checks$class_id, c(0L, 1L, 1L, 2L, 100L, 101L, 101L)), "All seven requested target boundaries")

# Synthetic data verifies selective outcome reading, boundary purging and
# training-only preprocessing. Test outcome strings are intentionally invalid.
fixture <- data.frame(rdt_id = as.character(1:6),
 start_time = c("2023-01-01T08:00:00Z", "2023-12-31T22:50:00Z", "2024-01-02T08:00:00Z",
                "2024-02-02T08:00:00Z", "2025-01-02T08:00:00Z", "2025-02-02T08:00:00Z"),
 start_year = c(2023,2023,2024,2024,2025,2025), source_year = c(2023,2023,2024,2024,2025,2025),
 rdt_lines_id = c("1,1,2", "99", "888", NA, "999", "999"),
 rdt_station_codes = c("UT,UT,ASD", NA, NA, "RTD", "SHL", NA),
 cause_group = c("known", "purged_only", "new_cause", NA, "test_only", "test_only"),
 cause_missing = c(FALSE,FALSE,FALSE,TRUE,FALSE,FALSE),
 end_time = c("2023-01-01T08:20:00Z", "2023-12-31T23:10:00Z",
              "2024-01-02T08:30:00Z", "2024-02-02T08:20:00Z", "LOCKED", "LOCKED"),
 duration_minutes = c("20", "20", "30", "20", "LOCKED", "LOCKED"))
tmp <- tempfile(fileext = ".csv")
write.csv(fixture, tmp, row.names = FALSE, na = "NA")
f <- prepare_data(data_path = tmp, expected_rows = 6L, include_retrospective_cause = TRUE)
check(identical(f$train$ids, "1") && identical(f$exclusions$rdt_id, "2"), "Unfinished training event purged at local midnight boundary")
check(identical(f$preprocessing$archived_context$top_routes, c("1", "2")), "Unique routes counted once per event; held-out and purged routes excluded")
check(!any(c("new_cause", "test_only", "purged_only") %in% f$preprocessing$archived_context$categorical_levels$cause_group), "Cause vocabulary learned from retained training only")
check(f$validation$X$archived_context[1, paste0("cause_group_", make.names("__UNSEEN__"))] == 1, "Unseen cause has explicit indicator")
features <- engineer_features(fixture, include_cause = TRUE)
check(features$archived_context$route_count[1] == 2 && features$archived_context$station_count[1] == 2 &&
  is.na(features$archived_context$station_count[3]), "Distinct route/station counts; missing stations remain unknown before imputation")
check(f$preprocessing$archived_context$medians[["station_count"]] == 2 &&
  f$validation$X$archived_context[1, "station_count"] == 0, "Missing station count uses training median and training scaling")
check(f$preprocessing$archived_context$medians[["stations_missing"]] == 0, "Missingness preprocessing is training-only")
check(all(is.na(f$test$y)), "Malformed test outcomes never parsed")

# Change held-out context drastically and verify the fitted preprocessing is unchanged.
fixture$rdt_lines_id[3:6] <- "777,888,999"
fixture$rdt_station_codes[3:6] <- "XX,YY,ZZ,UT,ASD,RTD"
fixture$cause_group[3:6] <- "changed_holdout"
write.csv(fixture, tmp, row.names = FALSE, na = "NA")
g <- prepare_data(data_path = tmp, expected_rows = 6L, include_retrospective_cause = TRUE)
check(identical(f$preprocessing, g$preprocessing) && identical(f$train$X, g$train$X), "Held-out feature changes cannot affect training transformations")
unlink(tmp)

# DST/local time handling: 06:30 UTC is 08:30 in July, a weekday rush hour.
summer <- fixture[1, , drop = FALSE]
summer$start_time <- "2024-07-01T06:30:00Z"
z <- engineer_features(summer)$time_only
check(z$hour == 8 && z$weekday == 1 && z$rush_hour == 1, "Europe/Amsterdam daylight-saving and rush-hour conversion")

# Exercise actual forward folds; do not expose 2025 outcomes.
folds <- list(c(2021,2022), c(2022,2023))
fold_counts <- lapply(folds, function(years) {
 z <- prepare_data(train_years = 2011:years[1], validation_years = years[2])
 check(all(z$train$metadata$local_start_year <= years[1]) &&
   identical(z$preprocessing$archived_context$fit_ids, z$train$ids), paste("Forward fold ending", years[1], "refits on correct rows"))
 data.frame(train_through = years[1], validation_year = years[2], train_n = length(z$train$ids),
   validation_n = length(z$validation$ids), boundary_exclusions = sum(z$exclusions$reason == "training_event_not_finished_before_validation"),
   outside_requested_years = sum(z$exclusions$reason == "outside_requested_years"))
})
check(identical(before, tools::md5sum(protected)), "Clean dataset and all Step 01 files unchanged")
write.csv(data.frame(check = checks, result = "PASS"), file.path(output, "validation_checks.csv"), row.names = FALSE)
write.csv(data.frame(split = names(p$audit$split_counts), records = as.integer(p$audit$split_counts)), file.path(output, "split_counts.csv"), row.names = FALSE)
write.csv(p$audit$boundary_checks, file.path(output, "class_boundary_checks.csv"), row.names = FALSE)
write.csv(p$exclusions, file.path(output, "exclusions.csv"), row.names = FALSE)
write.csv(do.call(rbind, fold_counts), file.path(output, "forward_fold_counts.csv"), row.names = FALSE)
write.csv(data.frame(feature_set = names(p$preprocessing), columns = vapply(p$train$X, ncol, integer(1)),
 retrospective = c(FALSE,TRUE), cause_included = FALSE), file.path(output, "feature_sets.csv"), row.names = FALSE)
write.csv(data.frame(label = p$class_levels, training_count = p$audit$training_class_counts), file.path(output, "training_class_counts.csv"), row.names = FALSE)
writeLines(c("# Preparation verification", "", paste(length(checks), "checks passed."),
 "No predictive models fitted. Test outcomes were not imported or evaluated.",
 paste("Dataset MD5:", p$audit$dataset_md5), paste("Classes MD5:", p$audit$classes_md5),
 paste("Target script MD5:", p$audit$target_script_md5), "", capture.output(sessionInfo())), file.path(output, "verification_report.md"))
cat(length(checks), "checks passed. Outputs:", output, "\n")
print(p$audit$split_counts)
print(do.call(rbind, fold_counts))
