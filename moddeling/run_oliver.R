# Reproduce Oliver's first model comparison (Steps 05, 06 and 08) from the BDMA root.
# Requires the saved baseline/logistic predictions from Mart (Steps 03/04).
# Optional installation: Rscript moddeling/05_random_forest/install_dependencies.R
# The full run order of all steps is documented in moddeling/README.md.
source("moddeling/05_random_forest/validate_tree_models.R")
source("moddeling/05_random_forest/run_random_forest.R")
source("moddeling/06_gradient_boosting/run_gradient_boosting.R")
source("moddeling/08_foutanalyse/run_error_analysis.R")
