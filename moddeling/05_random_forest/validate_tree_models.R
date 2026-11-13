# Focused synthetic checks: unseen labels, ordered columns, probability alignment,
# and fitting/predicting after serialization. No project outcomes are used.
source("moddeling/05_random_forest/tree_workflow.R")
source("moddeling/05_random_forest/random_forest.R")
source("moddeling/06_gradient_boosting/gradient_boosting.R")
classes <- evaluation_classes("moddeling/01_target/output/classes.csv")
set.seed(42)
x <- matrix(rnorm(240), ncol = 3, dimnames = list(NULL, c("a", "b", "c")))
# Deliberately nonadjacent class IDs; 99 classes absent in fitting.
y <- classes$label[ifelse(x[, 1] < -0.5, 2L, ifelse(x[, 1] > 0.5, 102L, 21L))]
f <- fit_forest(x, y, classes$label,
  data.frame(candidate = "test", mtry_rule = "sqrt", min_node_size = 5L), num_trees = 15L)
b <- fit_boosting(x, y, classes$label,
  data.frame(candidate = "test", max_depth = 2L, eta = 0.2, nrounds = 8L))
for (kind in c("forest", "boosting")) {
  model <- if (kind == "forest") f else b
  fun <- if (kind == "forest") predict_forest else predict_boosting
  p <- fun(model, x)
  stopifnot(identical(colnames(p), classes$label), all(p > 0), all(is.finite(p)),
    all(abs(rowSums(p) - 1) < 1e-10), sum(model$training_counts == 0) == 99L)
  path <- tempfile(fileext = ".rds"); saveRDS(model, path)
  stopifnot(isTRUE(all.equal(p, fun(readRDS(path), x), tolerance = 1e-10)))
  unlink(path)
  rejected <- try(fun(model, x[, 3:1]), silent = TRUE)
  stopifnot(inherits(rejected, "try-error"))
  # An observed outcome absent from fitting must still receive a valid probability.
  truth <- rep(classes$label[1], nrow(x))
  fixture <- list(validation = list(ids = as.character(seq_len(nrow(x))), y = truth),
    class_levels = classes$label, probability_columns = paste0("p_", classes$label))
  pred <- tree_prediction_table(fixture, p, "time_only", kind)
  e <- evaluate_predictions(pred, expected_ids = fixture$validation$ids, expected_true_class = truth)
  stopifnot(is.finite(e$summary$log_loss))
}
cat("Synthetic forest/boosting checks passed: absent/nonadjacent classes, fixed probability order, serialization, input rejection and shared evaluation.\n")
