# 102-class histogram XGBoost. Labels are fixed 0:101, including absent fold classes.
fit_boosting <- function(x, y, class_levels, settings, seed = 42L) {
  check_tree_input(x, y, class_levels)
  labels <- match(as.character(y), class_levels) - 1L
  dtrain <- xgboost::xgb.DMatrix(x, label = labels, nthread = 2L)
  params <- list(objective = "multi:softprob", num_class = length(class_levels),
    eval_metric = "mlogloss", tree_method = "hist", max_depth = settings$max_depth,
    eta = settings$eta, min_child_weight = 5, subsample = 0.8, colsample_bytree = 0.8,
    lambda = 1, nthread = 2L, seed = seed)
  fit <- xgboost::xgb.train(params = params, data = dtrain,
    nrounds = settings$nrounds, verbose = 0)
  list(fit = fit, class_levels = class_levels, feature_columns = colnames(x),
    training_counts = tabulate(labels + 1L, nbins = length(class_levels)),
    settings = settings, params = params, seed = seed, probability_floor = 1e-15)
}
predict_boosting <- function(model, x) {
  check_tree_prediction_input(model, x)
  d <- xgboost::xgb.DMatrix(x, nthread = 2L)
  raw <- predict(model$fit, d)
  if (is.null(dim(raw))) raw <- matrix(raw, nrow = nrow(x), byrow = TRUE)
  stopifnot(identical(dim(raw), c(nrow(x), length(model$class_levels))),
    all(is.finite(raw)), all(raw >= 0), all(abs(rowSums(raw) - 1) < 1e-5))
  # Match Step 04's fixed numerical floor, before the unmodified evaluator.
  p <- pmax(raw, model$probability_floor)
  p <- p / rowSums(p)
  colnames(p) <- model$class_levels
  p
}
