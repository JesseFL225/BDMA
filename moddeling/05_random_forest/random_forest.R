# 102-class probability forest. Source tree_workflow.R first.
fit_forest <- function(x, y, class_levels, settings, num_trees = 200L,
                       prior_weight = 0.01, seed = 42L) {
  check_tree_input(x, y, class_levels)
  stopifnot(prior_weight > 0, prior_weight < 1)
  counts <- tabulate(match(as.character(y), class_levels), nbins = length(class_levels))
  # Absent classes are reinserted at prediction; do not fabricate training cases.
  response <- factor(as.character(y), levels = class_levels[counts > 0])
  mtry <- if (settings$mtry_rule == "sqrt") floor(sqrt(ncol(x))) else floor(ncol(x) / 2)
  fit <- ranger::ranger(x = x, y = response, probability = TRUE, num.trees = num_trees,
    mtry = max(1L, mtry), min.node.size = settings$min_node_size,
    max.depth = 12L, num.threads = 2L, seed = seed,
    importance = "none", write.forest = TRUE, oob.error = FALSE)
  list(fit = fit, class_levels = class_levels, feature_columns = colnames(x),
    training_counts = counts, training_prior = (counts + 1) / (sum(counts) + length(counts)),
    prior_weight = prior_weight, settings = settings, num_trees = num_trees, mtry = mtry,
    max_depth = 12L, seed = seed)
}
predict_forest <- function(model, x) {
  if (!requireNamespace("ranger", quietly = TRUE)) stop("Install ranger before prediction.")
  check_tree_prediction_input(model, x)
  raw <- predict(model$fit, data = x, num.threads = 2L)$predictions
  stopifnot(is.matrix(raw), all(colnames(raw) %in% model$class_levels), all(is.finite(raw)),
    all(raw >= 0), all(abs(rowSums(raw) - 1) < 1e-8))
  p <- matrix(0, nrow(x), length(model$class_levels), dimnames = list(NULL, model$class_levels))
  p[, colnames(raw)] <- raw
  # Fixed 1% Laplace-smoothed TRAINING prior prevents zero probabilities for
  # rare/absent classes. It is part of the model, not clipping in the evaluator.
  p <- (1 - model$prior_weight) * p + model$prior_weight *
    matrix(model$training_prior, nrow(x), length(model$class_levels), byrow = TRUE)
  p / rowSums(p)
}
