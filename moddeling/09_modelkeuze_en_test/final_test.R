# Default: freeze provenance and reconstruct validation predictions WITHOUT
# loading test outcomes. Explicit --unlock-test evaluates the frozen models once.
source("moddeling/13_survival/survival.R")
source("moddeling/05_random_forest/random_forest.R")
source("moddeling/03_baselines/baselines.R")
output <- "moddeling/09_modelkeuze_en_test/output"
dir.create(output, recursive = TRUE, showWarnings = FALSE)
plan_path <- "moddeling/09_modelkeuze_en_test/selection_plan.csv"
plan <- read.csv(plan_path, stringsAsFactors = FALSE)
unlock <- "--unlock-test" %in% commandArgs(trailingOnly = TRUE)
marker <- file.path(output, "TEST_OUTCOMES_OPENED.txt")
if (file.exists(marker)) stop("2025 outcomes were already opened. Do not silently rerun or retune; see the recorded test outputs.")
stopifnot(identical(plan$key, c("survival_recent_time", "forest_context")),
 identical(plan$feature_set, c("time_only", "archived_context")), all(plan$train_end == 2023))
manifest_path <- file.path(output, "frozen_manifest.csv")
paths <- c(plan_path, "moddeling/09_modelkeuze_en_test/final_test.R",
 "moddeling/09_modelkeuze_en_test/test_diagnostics.R",
 "moddeling/09_modelkeuze_en_test/TEST_PROTOCOL.md",
 "data/disruptions_2011_2025_clean.csv", plan$model_path, plan$validation_predictions,
 "moddeling/01_target/output/classes.csv", "moddeling/01_target/define_duration_classes.R",
 "moddeling/02_voorbereiding/prepare_data.R", "moddeling/07_evaluatie/evaluate.R",
 "moddeling/03_baselines/baselines.R", "moddeling/05_random_forest/tree_workflow.R",
 "moddeling/05_random_forest/random_forest.R", "moddeling/13_survival/survival.R")
stopifnot(all(file.exists(paths)))
current <- data.frame(path = paths, md5 = unname(tools::md5sum(paths)))
if (!file.exists(manifest_path)) {
 if (unlock) stop("Run the default validation-only freeze first.")
 write.csv(current, manifest_path, row.names = FALSE)
} else stopifnot(identical(current, read.csv(manifest_path, stringsAsFactors = FALSE)))

models <- prepared <- list()
checks <- data.frame()
settings <- character()
for (i in seq_len(nrow(plan))) {
 z <- plan[i, ]; f <- z$feature_set
 d <- prepare_data(train_years = seq.int(z$train_start, z$train_end),
   include_retrospective_cause = TRUE, include_test_outcomes = FALSE)
 stopifnot(all(is.na(d$test$y)), all(is.na(d$test$duration_minutes)))
 model <- readRDS(z$model_path)
 stopifnot(identical(model$fit_ids, d$train$ids),
   identical(model$dataset_md5, d$audit$dataset_md5),
   identical(model$classes_md5, d$audit$classes_md5))
 predict_fun <- if (f == "time_only") predict_survival else predict_forest
 p <- predict_fun(model, d$validation$X[[f]])
 old <- read.csv(z$validation_predictions, check.names = FALSE)
 evaluate_predictions(old, expected_ids = d$validation$ids, expected_true_class = d$validation$y)
 stopifnot(max(abs(p - as.matrix(old[d$probability_columns]))) < 1e-10)
 checks <- rbind(checks, data.frame(key = z$key, check = "Training provenance and complete validation reconstruction; 2025 locked", passed = TRUE))
 models[[z$key]] <- model; prepared[[z$key]] <- d
 settings <- c(settings, paste("##", z$key), paste("Training events:", length(model$fit_ids)),
   paste("Feature columns:", length(model$feature_columns)),
   capture.output(str(model[c("settings", "params", "seed", "num_trees", "mtry", "max_depth", "prior_weight")])), "")
}
stopifnot(identical(prepared[[1]]$test$ids, prepared[[2]]$test$ids))
write.csv(checks, file.path(output, "pretest_checks.csv"), row.names = FALSE)
write.csv(data.frame(rdt_id = prepared[[1]]$test$ids), file.path(output, "frozen_test_ids.csv"), row.names = FALSE)
writeLines(c("# Frozen fitted-model settings", "", settings, capture.output(sessionInfo())),
 file.path(output, "frozen_settings.md"))
if (!unlock) {
 message("Freeze verified. All 2024 predictions reconstructed. No 2025 outcomes imported.")
} else {
 # Predictions are computed and saved before any test label is imported.
 forecast <- list()
 for (i in seq_len(nrow(plan))) {
   z <- plan[i, ]; d <- prepared[[z$key]]; f <- z$feature_set
   fun <- if (f == "time_only") predict_survival else predict_forest
   forecast[[z$key]] <- fun(models[[z$key]], d$test$X[[f]])
   if (f == "time_only") {
     baseline <- fit_global_baseline(d$train$y, d$class_levels, alpha = 1)
     bp <- predict_global_baseline(baseline, length(d$test$ids))
   } else {
     baseline <- fit_cause_baseline(d$train$y, prepared_cause_groups(d, "train"), d$class_levels, alpha = 1, lambda = 102)
     bp <- predict_cause_baseline(baseline, prepared_cause_groups(d, "test"))
   }
   forecast[[paste0(z$key, "_baseline")]] <- bp
   for (key in c(z$key, paste0(z$key, "_baseline"))) {
     p <- as.data.frame(forecast[[key]]); names(p) <- d$probability_columns
     write_gzip_csv(cbind(rdt_id = d$test$ids, p), file.path(output, paste0(key, "_before_labels.csv.gz")))
   }
 }
 write.csv(data.frame(path = list.files(output, pattern = "_before_labels.csv.gz$", full.names = TRUE),
   md5 = unname(tools::md5sum(list.files(output, pattern = "_before_labels.csv.gz$", full.names = TRUE)))),
   file.path(output, "prediction_hashes_before_labels.csv"), row.names = FALSE)
 writeLines(c("User authorized freezing the selected models and evaluating 2025 on 2026-11-13.",
   "Test outcomes are now being opened. No further selection or tuning on 2025.",
   paste("Execution timestamp:", format(Sys.time(), tz = "Europe/Amsterdam", usetz = TRUE))), marker)
 # This is the first requested import of the 2025 outcomes in model development.
 truth <- prepare_data(include_retrospective_cause = TRUE, include_test_outcomes = TRUE)
 stopifnot(identical(truth$test$ids, prepared[[1]]$test$ids), !anyNA(truth$test$y))
 evaluations <- list()
 for (i in seq_len(nrow(plan))) {
   z <- plan[i, ]
   for (key in c(z$key, paste0(z$key, "_baseline"))) {
     p <- forecast[[key]]
     meta <- data.frame(rdt_id = truth$test$ids, split = "test", model = key,
       feature_set = z$feature_set, true_class = as.character(truth$test$y),
       predicted_class = truth$class_levels[max.col(p, ties.method = "first")])
     tab <- as.data.frame(p); names(tab) <- truth$probability_columns
     pred <- cbind(meta, tab)
     e <- evaluate_predictions(pred, expected_ids = truth$test$ids,
       expected_true_class = truth$test$y, allow_test = TRUE)
     path <- file.path(output, paste0(key, "_test_predictions.csv.gz"))
     write_gzip_csv(pred, path)
     restored <- evaluate_predictions(read.csv(path, check.names = FALSE), expected_ids = truth$test$ids,
       expected_true_class = truth$test$y, allow_test = TRUE)
     stopifnot(isTRUE(all.equal(e$summary, restored$summary, tolerance = 1e-10)))
     save_evaluation(e, output, key)
     evaluations[[key]] <- e
   }
 }
 write.csv(do.call(rbind, lapply(evaluations, `[[`, "summary")),
   file.path(output, "test_comparison.csv"), row.names = FALSE)
 stopifnot(identical(current, data.frame(path = paths, md5 = unname(tools::md5sum(paths)))))
 writeLines(c("Frozen source/data/model hashes unchanged after evaluation.",
   "Four prediction tables pass shared evaluator and serialization checks.",
   "Both chosen models were fitted before 2025 labels were imported; no refitting on 2024 or 2025.",
   "Baselines use each model's training cohort only; no model selection based on test scores."),
   file.path(output, "test_verification.md"))
 source("moddeling/09_modelkeuze_en_test/test_diagnostics.R")
}
