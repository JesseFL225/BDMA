# Discrete-time hazard boosting, fitted as a person-period binomial likelihood.
source("moddeling/05_random_forest/tree_workflow.R")

risk_rows <- function(class_index, k = 102L) {
  stopifnot(length(class_index) > 0, !anyNA(class_index),
    all(class_index %in% seq_len(k)))
  n <- pmin(class_index, k - 1L)
  person <- rep(seq_along(n), n)
  interval <- sequence(n)
  list(person = person, interval = interval,
    event = as.integer(interval == class_index[person]))
}

hazard_to_probability <- function(h) {
  stopifnot(is.matrix(h), all(is.finite(h)), all(h >= 0 & h <= 1))
  p <- matrix(0, nrow(h), ncol(h) + 1L)
  remaining <- rep(1, nrow(h))
  for (j in seq_len(ncol(h))) {
    p[, j] <- remaining * h[, j]
    remaining <- remaining * (1 - h[, j])
  }
  p[, ncol(p)] <- remaining
  p
}

period_matrix <- function(x, person, interval) {
  # Dense zero values are meaningful. Sparse representation is used consistently
  # for both fitting and prediction (implicit zeros share the missing branch).
  z <- cbind(Matrix::Matrix(x, sparse = TRUE)[person, , drop = FALSE],
    interval_index = as.numeric(interval))
  as(z, "dgCMatrix")
}

fit_survival <- function(x, y, class_levels, settings, seed = 42L) {
  check_tree_input(x, y, class_levels)
  k <- length(class_levels)
  index <- match(as.character(y), class_levels)
  counts <- tabulate(index, nbins = k)
  # One pseudo-observation per class: an empirical smoothed marginal hazard.
  mass <- counts + 1
  hazard <- head(mass / rev(cumsum(rev(mass))), -1L)
  offset <- qlogis(hazard)
  r <- risk_rows(index, k)
  expanded <- period_matrix(x, r$person, r$interval)
  d <- xgboost::xgb.DMatrix(expanded, label = r$event,
    base_margin = offset[r$interval], nthread = 2L)
  params <- list(objective = "binary:logistic", eval_metric = "logloss",
    tree_method = "hist", max_depth = settings$max_depth, eta = settings$eta,
    min_child_weight = 20, lambda = 10, subsample = 1,
    colsample_bytree = 1, nthread = 2L, seed = seed)
  fit <- xgboost::xgb.train(params = params, data = d,
    nrounds = settings$nrounds, verbose = 0)
  list(fit = fit, offset = offset, class_levels = class_levels,
    feature_columns = colnames(x), training_counts = counts, settings = settings,
    params = params, seed = seed, expanded_n = length(r$event), probability_floor = 1e-15)
}

predict_survival <- function(model, x, batch_size = 300L) {
  check_tree_prediction_input(model, x)
  k <- length(model$class_levels)
  p <- matrix(NA_real_, nrow(x), k)
  for (start in seq.int(1L, nrow(x), by = batch_size)) {
    rows <- seq.int(start, min(nrow(x), start + batch_size - 1L))
    person <- rep(seq_along(rows), each = k - 1L)
    interval <- rep(seq_len(k - 1L), times = length(rows))
    d <- xgboost::xgb.DMatrix(period_matrix(x[rows, , drop = FALSE], person, interval),
      base_margin = model$offset[interval], nthread = 2L)
    h <- matrix(predict(model$fit, d), nrow = length(rows), byrow = TRUE)
    p[rows, ] <- hazard_to_probability(h)
  }
  # Same fixed numerical floor as existing boosting/logistic models.
  p <- pmax(p, model$probability_floor)
  p <- p / rowSums(p)
  colnames(p) <- model$class_levels
  p
}
