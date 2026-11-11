# Reusable frequency baselines. Base R only; no file writes on sourcing.
# The caller supplies Step 02 training labels and fixed class order.
fit_global_baseline <- function(y, class_levels, alpha = 1) {
  if (length(class_levels) != 102L || anyNA(class_levels) || anyDuplicated(class_levels))
    stop("Require the fixed 102 unique class labels.")
  if (!length(y) || anyNA(y) || any(!as.character(y) %in% class_levels))
    stop("Training labels must be nonmissing fixed class labels.")
  if (length(alpha) != 1L || !is.finite(alpha) || alpha <= 0)
    stop("alpha must be a positive finite scalar.")
  counts <- tabulate(match(as.character(y), class_levels), nbins = length(class_levels))
  probabilities <- (counts + alpha) / (length(y) + length(class_levels) * alpha)
  names(probabilities) <- class_levels
  list(class_levels = class_levels, counts = counts, n_train = length(y),
       alpha = alpha, probabilities = probabilities)
}

predict_global_baseline <- function(fit, n) {
  if (length(n) != 1L || !is.finite(n) || n < 0 || n != as.integer(n)) stop("Invalid prediction row count.")
  matrix(rep(fit$probabilities, each = n), nrow = n, ncol = length(fit$class_levels),
         dimnames = list(NULL, fit$class_levels))
}

# Decode Step 02's existing cause one-hot columns, NOT the raw CSV. This does
# not refit or recreate preprocessing; training vocabulary and unseen/missing
# handling are exactly those already fitted by Step 02.
prepared_cause_groups <- function(prepared, split) {
  prep <- prepared$preprocessing$archived_context
  levels <- prep$categorical_levels$cause_group
  if (is.null(levels) || !isTRUE(prepared$audit$retrospective_cause))
    stop("Call prepare_data(include_retrospective_cause = TRUE) for the cause baseline.")
  columns <- paste("cause_group", make.names(levels, unique = TRUE), sep = "_")
  x <- prepared[[split]]$X$archived_context
  if (!all(columns %in% colnames(x))) stop("Prepared cause columns missing.")
  block <- x[, columns, drop = FALSE]
  if (any(!is.finite(block)) || any(!block %in% c(0, 1)) || any(rowSums(block) != 1))
    stop("Cause encoding must have exactly one active Step 02 category per row.")
  levels[max.col(block, ties.method = "first")]
}

# Prior mass lambda is fixed before looking at validation scores.
# P(k|g) = (n_gk + lambda * P_global(k)) / (n_g + lambda).
fit_cause_baseline <- function(y, groups, class_levels, alpha = 1, lambda = 102) {
  if (length(groups) != length(y) || anyNA(groups) || any(!nzchar(groups)))
    stop("Use explicit Step 02 missing/unseen cause tokens, not NA or blank groups.")
  if (length(lambda) != 1L || !is.finite(lambda) || lambda <= 0)
    stop("lambda must be a positive finite scalar.")
  global <- fit_global_baseline(y, class_levels, alpha)
  groups <- as.character(groups)
  vocabulary <- sort(unique(groups))
  counts <- matrix(0, length(vocabulary), length(class_levels),
                   dimnames = list(vocabulary, class_levels))
  for (i in seq_along(vocabulary)) counts[i, ] <- tabulate(
    match(as.character(y)[groups == vocabulary[i]], class_levels), nbins = length(class_levels))
  totals <- rowSums(counts)
  probabilities <- (counts + matrix(rep(lambda * global$probabilities, each = length(vocabulary)),
    nrow = length(vocabulary))) / (totals + lambda)
  list(global = global, groups = vocabulary, counts = counts, group_n = totals,
       probabilities = probabilities, lambda = lambda, class_levels = class_levels)
}

predict_cause_baseline <- function(fit, groups) {
  if (anyNA(groups) || any(!nzchar(groups))) stop("Cause groups need explicit missing/unseen tokens.")
  x <- predict_global_baseline(fit$global, length(groups))
  position <- match(as.character(groups), fit$groups)
  known <- which(!is.na(position))
  x[known, ] <- fit$probabilities[position[known], , drop = FALSE]
  x
}

baseline_prediction_table <- function(prepared, probabilities, model, feature_set, split = "validation") {
  part <- prepared[[split]]
  if (split != "validation") stop("Step 03 produces validation predictions only.")
  if (!is.matrix(probabilities) || !identical(colnames(probabilities), prepared$class_levels) ||
      nrow(probabilities) != length(part$ids)) stop("Probability dimensions/order do not match prepared split.")
  if (anyNA(part$y)) stop("Validation labels unavailable.")
  result <- data.frame(rdt_id = part$ids, split = split, model = model, feature_set = feature_set,
    true_class = as.character(part$y),
    predicted_class = prepared$class_levels[max.col(probabilities, ties.method = "first")])
  probabilities <- as.data.frame(probabilities)
  names(probabilities) <- prepared$probability_columns
  cbind(result, probabilities)
}
