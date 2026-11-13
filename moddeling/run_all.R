# =============================================================================
# One entry point for the whole analysis — safe to run at any time
# =============================================================================
# Run from the repository root:   Rscript moddeling/run_all.R
#
# What it does (a few minutes, no model training):
#   1. Re-runs the automated checks of the shared preparation, evaluator,
#      survival model and history features.
#   2. Independently re-verifies the saved validation and final-test predictions.
#   3. Re-runs the linkage-pilot unit tests.
#   4. Rebuilds the per-year data profile and every report table and figure
#      (moddeling/16_report_inputs/output/).
#
# What it deliberately does NOT do:
#   - Retrain models. Retraining Steps 05 and 13 would overwrite model files that
#     are frozen for the 2025 test (moddeling/09_modelkeuze_en_test/output/frozen_manifest.csv)
#     and break the test's provenance checks. The retraining commands are printed
#     at the end for anyone who wants to reproduce the training in a separate copy.
#   - Re-run the final test. 2025 has been used once (see TEST_OUTCOMES_OPENED.txt).
# =============================================================================

steps <- list(
  c("Rscript", "moddeling/02_voorbereiding/validate_preparation.R", "Shared preparation checks (Step 02)"),
  c("Rscript", "moddeling/07_evaluatie/validate_evaluation.R",      "Shared evaluator checks (Step 07)"),
  c("Rscript", "moddeling/11_historische_kenmerken/validate_history.R", "History-feature checks (Step 11)"),
  c("Rscript", "moddeling/13_survival/validate_survival.R",          "Survival-model checks (Step 13)"),
  c("python3", "moddeling/13_survival/verify_predictions.py",        "Re-verify saved validation predictions (Step 13)"),
  c("python3", "moddeling/09_modelkeuze_en_test/verify_saved_test.py", "Re-verify saved final-test predictions (Step 09)"),
  c("python3", "moddeling/15_koppelpilot/test_pilot.py",             "Linkage-pilot unit tests (Step 15)"),
  c("python3", "Data Cleaning/yearly_profile.py",                    "Per-year profile of the clean data"),
  c("Rscript", "moddeling/16_report_inputs/make_report_inputs.R",    "All report tables and figures (Step 16)"))

# The Step 02 and 07 checks rewrite a verification report that records the R
# version and machine of the ORIGINAL run. Keep that record: save the reports
# now and put them back afterwards (the checks themselves must still pass).
kept_reports <- c("moddeling/02_voorbereiding/output/verification_report.md",
                  "moddeling/07_evaluatie/output/verification_report.md")
kept_content <- lapply(kept_reports, function(path) readBin(path, "raw", file.size(path)))

# Step 0: every file frozen for the 2025 test (code, data, models, predictions)
# must still match the hash recorded before the test. Even a comment change fails.
# Fitted models (output/models/*.rds) are Git-ignored, so a fresh clone does not
# have them: a missing model file is reported and skipped; a present but
# different file is an error.
frozen <- read.csv("moddeling/09_modelkeuze_en_test/output/frozen_manifest.csv", stringsAsFactors = FALSE)
present <- file.exists(frozen$path)
changed <- frozen$path[present & unname(tools::md5sum(frozen$path[present]))[match(frozen$path, frozen$path[present])] != frozen$md5]
changed <- changed[!is.na(changed)]
if (length(changed)) stop("Frozen files changed (restore them with git checkout):\n  ",
                          paste(changed, collapse = "\n  "))
if (any(!present & !grepl("/output/models/", frozen$path)))
  stop("Frozen files missing: ", paste(frozen$path[!present & !grepl("/output/models/", frozen$path)], collapse = ", "))
cat(sprintf("[0/%d] %d frozen test files unchanged", length(steps), sum(present)))
if (any(!present)) cat(sprintf("; %d Git-ignored model file(s) not in this copy, skipped", sum(!present)))
cat("\n")

tryCatch({
  for (i in seq_along(steps)) {
    s <- steps[[i]]
    cat(sprintf("\n[%d/%d] %s\n", i, length(steps), s[3]))
    status <- system2(s[1], shQuote(s[2]), stdout = "", stderr = "")
    if (!identical(status, 0L)) stop(sprintf("Step failed: %s %s (exit code %s)", s[1], s[2], status))
  }
}, finally = {
  # Byte-exact restore of the original verification reports, also after a failure.
  for (k in seq_along(kept_reports)) writeBin(kept_content[[k]], kept_reports[k])
})

cat("\nAll checks passed and all report inputs are rebuilt.\n",
    "\nTo reproduce the model TRAINING (long; do this in a separate copy of the repository,",
    "\nbecause it overwrites frozen model files), run in this order:",
    "\n  Rscript \"Data Cleaning/clean_disruptions.R\"",
    "\n  Rscript moddeling/03_baselines/run_baselines.R",
    "\n  Rscript moddeling/04_logistic_regression/run_logistic_regression.R",
    "\n  Rscript moddeling/run_oliver.R                      # Steps 05, 06, 08",
    "\n  Rscript moddeling/10_regressie_experiment/run_regression.R",
    "\n  Rscript moddeling/11_historische_kenmerken/run_history_regression.R",
    "\n  Rscript moddeling/13_survival/run_survival.R\n", sep = "")
