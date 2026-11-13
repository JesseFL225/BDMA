# Fixed-setting training-period sensitivity; do not retune on 2024.
source("moddeling/13_survival/survival.R")
output <- "moddeling/13_survival/output"
selected <- read.csv(file.path(output, "selected_settings.csv"))
grid <- read.csv(file.path(output, "candidate_grid.csv"))
recent <- prepare_data(train_years = 2017:2023,
 include_retrospective_cause = TRUE, include_test_outcomes = FALSE)
stopifnot(all(is.na(recent$test$y)), all(is.na(recent$test$duration_minutes)))
for (f in c("time_only", "archived_context")) {
 message("Recent-period survival sensitivity: ", f)
 setting <- grid[grid$candidate == selected$candidate[selected$feature_set == f], ]
 model <- fit_survival(recent$train$X[[f]], recent$train$y, recent$class_levels, setting)
 model$fit_ids <- recent$train$ids
 model$dataset_md5 <- recent$audit$dataset_md5
 model$classes_md5 <- recent$audit$classes_md5
 model$feature_set <- f
 model$package_version <- as.character(packageVersion("xgboost"))
 p <- predict_survival(model, recent$validation$X[[f]])
 pred <- tree_prediction_table(recent, p, f, "discrete_time_hazard_since2017")
 evaluate_predictions(pred, expected_ids = recent$validation$ids, expected_true_class = recent$validation$y)
 write_gzip_csv(pred, file.path(output, paste0(f, "_since2017_validation_predictions.csv.gz")))
 saveRDS(model, file.path(output, "models", paste0(f, "_since2017.rds")))
 stopifnot(max(abs(p[1:10, ] - predict_survival(readRDS(file.path(output, "models",
   paste0(f, "_since2017.rds"))), recent$validation$X[[f]][1:10, ]))) < 1e-10)
 write.csv(data.frame(rdt_id = recent$train$ids),
  file.path(output, paste0(f, "_since2017_fit_ids.csv")), row.names = FALSE)
 rm(model, p, pred); gc(FALSE)
}
