# Run from BDMA root: Rscript moddeling/06_gradient_boosting/run_gradient_boosting.R
source("moddeling/05_random_forest/tree_workflow.R")
source("moddeling/06_gradient_boosting/gradient_boosting.R")
grid <- data.frame(candidate = c("depth2_round80", "depth3_round80", "depth2_round160"),
  max_depth = c(2L, 3L, 2L), eta = c(0.1, 0.1, 0.1), nrounds = c(80L, 80L, 160L))
run_tree_workflow("xgboost_multiclass", grid, fit_boosting, predict_boosting,
  "moddeling/06_gradient_boosting/output", "xgboost")
