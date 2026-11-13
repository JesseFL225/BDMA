# Run from BDMA root: Rscript moddeling/05_random_forest/run_random_forest.R
source("moddeling/05_random_forest/tree_workflow.R")
source("moddeling/05_random_forest/random_forest.R")
grid <- data.frame(candidate = c("sqrt_leaf100", "sqrt_leaf30", "half_leaf100"),
  mtry_rule = c("sqrt", "sqrt", "half"), min_node_size = c(100L, 30L, 100L))
run_tree_workflow("random_forest_prior_smoothed", grid, fit_forest, predict_forest,
  "moddeling/05_random_forest/output", "ranger")
