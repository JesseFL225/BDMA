# Oliver's runner helpers. Shared preparation/evaluation are imported, not copied.
if (dir.exists(".R-library")) .libPaths(c(normalizePath(".R-library"), .libPaths()))
source("moddeling/02_voorbereiding/prepare_data.R")
source("moddeling/07_evaluatie/evaluate.R")

check_tree_input <- function(x, y, levels) {
  stopifnot(is.matrix(x), is.numeric(x), all(is.finite(x)), nrow(x) == length(y),
    nrow(x) > 0, !is.null(colnames(x)), !anyDuplicated(colnames(x)),
    length(levels) == 102L, !anyNA(y), all(as.character(y) %in% levels))
}
check_tree_prediction_input <- function(model, x) {
  if (!is.matrix(x) || !identical(colnames(x), model$feature_columns) || any(!is.finite(x)))
    stop("Prediction matrix must have finite values and exactly the fitted columns in order.")
}
tree_prediction_table <- function(prepared, p, feature_set, model) {
  part <- prepared$validation
  stopifnot(nrow(p) == length(part$ids), identical(colnames(p), prepared$class_levels))
  meta <- data.frame(rdt_id = part$ids, split = "validation", model = model,
    feature_set = feature_set, true_class = as.character(part$y),
    predicted_class = prepared$class_levels[max.col(p, ties.method = "first")])
  p <- as.data.frame(p); names(p) <- prepared$probability_columns
  cbind(meta, p)
}
write_gzip_csv <- function(value, path) {
  con <- gzfile(path, "wt")
  tryCatch(write.csv(value, con, row.names = FALSE), finally = close(con))
}
save_evaluation <- function(e, output, feature_set) {
  for (name in c("summary", "per_class", "ordinal_summary"))
    write.csv(e[[name]], file.path(output, paste0(feature_set, "_", name, ".csv")), row.names = FALSE)
  write_gzip_csv(e$per_observation, file.path(output, paste0(feature_set, "_per_observation.csv.gz")))
  write.csv(as.data.frame.matrix(e$confusion_matrix),
    file.path(output, paste0(feature_set, "_confusion_matrix.csv")))
}
protected_modelling_files <- function() c(
  list.files("data", full.names = TRUE, pattern = "csv$"),
  unlist(lapply(c("01_target", "02_voorbereiding", "03_baselines", "04_logistic_regression", "07_evaluatie"),
    function(s) list.files(file.path("moddeling", s), recursive = TRUE, full.names = TRUE))))

run_tree_workflow <- function(model_name, grid, fit_fun, predict_fun, output, package) {
  if (!requireNamespace(package, quietly = TRUE)) stop(paste("Install R package", package, "before running."))
  set.seed(42)
  started <- Sys.time()
  protected <- protected_modelling_files(); before <- tools::md5sum(protected)
  dir.create(file.path(output, "models"), recursive = TRUE, showWarnings = FALSE)
  write.csv(grid, file.path(output, "candidate_grid.csv"), row.names = FALSE)
  feature_sets <- c("time_only", "archived_context")
  tuning <- data.frame()
  for (year in c(2021L, 2022L)) {
    fold <- prepare_data(train_years = 2011:year, validation_years = year + 1L,
      include_retrospective_cause = TRUE, include_test_outcomes = FALSE)
    stopifnot(all(is.na(fold$test$y)), all(is.na(fold$test$duration_minutes)))
    for (f in feature_sets) for (i in seq_len(nrow(grid))) {
      message(model_name, " ", f, " fold ", year + 1L, " candidate ", grid$candidate[i])
      clock <- Sys.time()
      model <- fit_fun(fold$train$X[[f]], fold$train$y, fold$class_levels, grid[i, ])
      p <- predict_fun(model, fold$validation$X[[f]])
      pred <- tree_prediction_table(fold, p, f, model_name)
      e <- evaluate_predictions(pred, expected_ids = fold$validation$ids, expected_true_class = fold$validation$y)
      tuning <- rbind(tuning, data.frame(feature_set = f, candidate = grid$candidate[i],
        train_through = year, validation_year = year + 1L, train_n = length(fold$train$ids),
        validation_n = length(fold$validation$ids), feature_columns = ncol(fold$train$X[[f]]),
        minimum_training_class = min(model$training_counts), absent_classes = sum(model$training_counts == 0),
        preprocessing_training_only = identical(fold$preprocessing[[f]]$fit_ids, fold$train$ids),
        log_loss = e$summary$log_loss, accuracy = e$summary$accuracy,
        elapsed_seconds = as.numeric(difftime(Sys.time(), clock, units = "secs"))))
      message("  log loss: ", round(e$summary$log_loss, 6))
      write.csv(tuning, file.path(output, "tuning_fold_results.csv"), row.names = FALSE)
      rm(model, p, pred, e); gc(FALSE)
    }
    rm(fold); gc(FALSE)
  }
  stopifnot(all(is.finite(tuning$log_loss)), all(tuning$validation_year < 2024),
    all(tuning$preprocessing_training_only))
  summary <- do.call(rbind, lapply(feature_sets, function(f) do.call(rbind,
    lapply(grid$candidate, function(candidate) {
      z <- tuning[tuning$feature_set == f & tuning$candidate == candidate, ]
      stopifnot(identical(sort(z$validation_year), c(2022L, 2023L)))
      data.frame(feature_set = f, candidate = candidate,
        mean_log_loss = mean(z$log_loss), sd_log_loss = sd(z$log_loss))
    }))))
  selected <- do.call(rbind, lapply(feature_sets, function(f) {
    z <- summary[summary$feature_set == f, ]
    z[order(z$mean_log_loss, match(z$candidate, grid$candidate)), ][1, ]
  }))
  rownames(selected) <- NULL
  write.csv(summary, file.path(output, "tuning_summary.csv"), row.names = FALSE)
  write.csv(selected, file.path(output, "selected_settings.csv"), row.names = FALSE)
  # Candidate selection is now frozen, before any 2024 scoring.
  prepared <- prepare_data(include_retrospective_cause = TRUE, include_test_outcomes = FALSE)
  checks <- data.frame(check = "2025 outcomes stay locked",
    passed = all(is.na(prepared$test$y)) && all(is.na(prepared$test$duration_minutes)))
  evaluations <- list()
  for (f in feature_sets) {
    candidate <- selected$candidate[selected$feature_set == f]
    message("Final fit ", model_name, " ", f, " candidate ", candidate)
    model <- fit_fun(prepared$train$X[[f]], prepared$train$y, prepared$class_levels,
      grid[grid$candidate == candidate, ])
    model$dataset_md5 <- prepared$audit$dataset_md5
    model$classes_md5 <- prepared$audit$classes_md5
    model$feature_set <- f
    model$fit_ids <- prepared$train$ids
    model$package_version <- as.character(utils::packageVersion(package))
    p <- predict_fun(model, prepared$validation$X[[f]])
    pred <- tree_prediction_table(prepared, p, f, model_name)
    e <- evaluate_predictions(pred, expected_ids = prepared$validation$ids,
      expected_true_class = prepared$validation$y)
    evaluations[[f]] <- e
    pred_path <- file.path(output, paste0(f, "_validation_predictions.csv.gz"))
    write_gzip_csv(pred, pred_path)
    save_evaluation(e, output, f)
    model_path <- file.path(output, "models", paste0(f, ".rds"))
    saveRDS(model, model_path) # Local ignored cache: regenerate with this script.
    restored <- readRDS(model_path)
    ncheck <- seq_len(min(20L, nrow(prepared$validation$X[[f]])))
    same <- isTRUE(all.equal(p[ncheck, , drop = FALSE],
      predict_fun(restored, prepared$validation$X[[f]][ncheck, , drop = FALSE]), tolerance = 1e-10))
    saved <- read.csv(pred_path, check.names = FALSE)
    scored <- evaluate_predictions(saved, expected_ids = prepared$validation$ids,
      expected_true_class = prepared$validation$y)
    checks <- rbind(checks, data.frame(check = paste(f, c("saved model reproduces predictions",
      "saved CSV reproduces metrics", "fit IDs match training cohort")),
      passed = c(same, isTRUE(all.equal(e$summary, scored$summary, tolerance = 1e-10)),
        identical(model$fit_ids, prepared$train$ids))))
    rm(model, restored, p, pred, saved, scored); gc(FALSE)
  }
  comparison <- do.call(rbind, lapply(evaluations, `[[`, "summary")); rownames(comparison) <- NULL
  write.csv(comparison, file.path(output, "validation_comparison.csv"), row.names = FALSE)
  checks <- rbind(checks, data.frame(check = "Dataset and Mart-owned steps unchanged",
    passed = identical(before, tools::md5sum(protected))))
  write.csv(checks, file.path(output, "validation_checks.csv"), row.names = FALSE)
  stopifnot(all(checks$passed))
  writeLines(c(paste("#", model_name, "verification"), "",
    paste(nrow(checks), "checks passed. Training seed 42; chronological 2022/2023 tuning folds."),
    paste("Runtime seconds:", round(as.numeric(difftime(Sys.time(), started, units = "secs")), 1)),
    paste("Dataset MD5:", prepared$audit$dataset_md5),
    paste("Classes MD5:", prepared$audit$classes_md5),
    "Candidate selection uses equal weight per tuning year. Grid order breaks ties.",
    "Identical shared preparation and evaluation. Archived context includes retrospective cause.",
    "2025 outcomes never imported/evaluated. Fitted models are local ignored caches.",
    "", capture.output(sessionInfo())), file.path(output, "verification_report.md"))
  print(selected); print(comparison)
  invisible(comparison)
}
