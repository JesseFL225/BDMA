# Experiment 1: same features, continuous minutes, absolute-error objective.
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
source("moddeling/02_voorbereiding/prepare_data.R")

regression_metrics <- function(truth, prediction, class_assigner) {
  stopifnot(length(truth) == length(prediction), length(truth) > 0,
    all(is.finite(truth)), all(is.finite(prediction)), all(truth >= 0), all(prediction >= 0))
  error <- prediction - truth
  data.frame(n = length(truth), mae_minutes = mean(abs(error)),
    median_absolute_error_minutes = median(abs(error)), rmse_minutes = sqrt(mean(error^2)),
    within_10_pct = 100 * mean(abs(error) <= 10), within_20_pct = 100 * mean(abs(error) <= 20),
    exact_class_pct = 100 * mean(class_assigner(truth) == class_assigner(prediction)),
    underestimation_pct = 100 * mean(error < 0), mean_signed_error_minutes = mean(error))
}
fit_duration_regression <- function(x, y, settings) {
  stopifnot(is.matrix(x), nrow(x) == length(y), all(is.finite(x)),
    all(is.finite(y)), all(y > 0), !is.null(colnames(x)))
  if (!requireNamespace("xgboost", quietly = TRUE)) stop("Install xgboost first.")
  params <- list(objective = "reg:absoluteerror", eval_metric = "mae",
    tree_method = "hist", max_depth = settings$max_depth, eta = 0.05,
    min_child_weight = 10, subsample = 0.8, colsample_bytree = 0.8,
    lambda = 1, base_score = median(y), nthread = 2L, seed = 42L)
  d <- xgboost::xgb.DMatrix(x, label = y, nthread = 2L)
  fit <- xgboost::xgb.train(params = params, data = d, nrounds = settings$nrounds, verbose = 0)
  list(fit = fit, settings = settings, params = params, feature_columns = colnames(x),
    training_median = median(y))
}
predict_duration_regression <- function(model, x) {
  stopifnot(is.matrix(x), identical(colnames(x), model$feature_columns), all(is.finite(x)))
  p <- as.numeric(predict(model$fit, xgboost::xgb.DMatrix(x, nthread = 2L)))
  stopifnot(length(p) == nrow(x), all(is.finite(p)))
  pmax(0, p) # Physical nonnegative duration; no rounding or upper cap.
}
