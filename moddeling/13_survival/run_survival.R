# Run from repository root. No 2025 outcomes are requested.
source("moddeling/13_survival/validate_survival.R")
grid <- data.frame(candidate = c("depth2_round100", "depth3_round100", "depth2_round250"),
 max_depth = c(2L, 3L, 2L), eta = .05, nrounds = c(100L, 100L, 250L))
run_tree_workflow("discrete_time_hazard_xgboost", grid, fit_survival, predict_survival,
 "moddeling/13_survival/output", "xgboost")
source("moddeling/13_survival/run_recent.R")
source("moddeling/13_survival/evaluate_survival.R")
