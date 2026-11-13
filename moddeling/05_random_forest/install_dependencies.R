# Optional explicit setup from BDMA root. Nothing is installed on sourcing models.
# Project-local library is ignored by Git and does not modify system libraries.
dir.create(".R-library", showWarnings = FALSE)
.libPaths(c(normalizePath(".R-library"), .libPaths()))
required <- c("ranger", "xgboost")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, lib = ".R-library", repos = "https://cloud.r-project.org")
for (package in required) cat(package, as.character(packageVersion(package)), "\n")
