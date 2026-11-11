# Algorithm-independent evaluation. Base R only; no writes or model fitting.
# Source from the repository root. Uses the frozen Step 01 class order.

evaluation_classes <- function(path) {
  x <- read.csv(path, stringsAsFactors = FALSE)
  required <- c("class_id", "label", "lower_inclusive_minutes", "upper_exclusive_minutes")
  if (!identical(names(x), required) || nrow(x) != 102L || anyNA(x) ||
      !identical(x$class_id, 0:101) || anyDuplicated(x$label) ||
      !identical(x$lower_inclusive_minutes, seq(0L, 1010L, 10L)) ||
      !all(head(x$upper_exclusive_minutes, -1) == tail(x$lower_inclusive_minutes, -1)) ||
      tail(x$upper_exclusive_minutes, 1) != Inf)
    stop("Invalid frozen classes.csv: expected 102 ordered contiguous classes, IDs 0–101.", call. = FALSE)
  x
}

# One model, feature set and split per call. To evaluate multiple models, call
# separately with the SAME expected_ids and expected_true_class in row order.
# This makes cohort completeness verifiable without silently joining/sorting.
evaluate_predictions <- function(predictions,
    classes_path = "moddeling/01_target/output/classes.csv",
    expected_ids = NULL, expected_true_class = NULL,
    probability_tolerance = 1e-8, allow_test = FALSE) {
  fail <- function(message) stop(message, call. = FALSE)
  if (!is.numeric(probability_tolerance) || length(probability_tolerance) != 1L ||
      !is.finite(probability_tolerance) || probability_tolerance <= 0 || probability_tolerance > 1e-4)
    fail("probability_tolerance must be a finite scalar in (0, 1e-4].")
  if (!is.logical(allow_test) || length(allow_test) != 1L || is.na(allow_test))
    fail("allow_test must be TRUE or FALSE.")
  classes <- evaluation_classes(classes_path)
  labels <- classes$label
  probability_columns <- paste0("p_", labels)
  metadata_columns <- c("rdt_id", "split", "model", "feature_set", "true_class", "predicted_class")
  if (!is.data.frame(predictions) || nrow(predictions) == 0L)
    fail("predictions must be a nonempty data.frame.")
  if (anyDuplicated(names(predictions))) fail("Duplicate input column names are not allowed.")
  if (!identical(names(predictions), c(metadata_columns, probability_columns)))
    fail("Column names/order must be the six metadata columns followed by all 102 probability columns in classes.csv order; no extra columns.")
  for (nm in metadata_columns) {
    v <- predictions[[nm]]
    if (!(is.character(v) || is.factor(v) || (nm == "rdt_id" && is.numeric(v))))
      fail(paste(nm, "must be character/factor; IDs may also be numeric."))
    if (anyNA(v) || any(!nzchar(trimws(as.character(v))))) fail(paste("Missing/blank", nm, "values."))
    if (is.numeric(v) && any(!is.finite(v))) fail("IDs must be finite.")
  }
  ids <- as.character(predictions$rdt_id)
  if (anyDuplicated(ids)) fail("Duplicate disruption IDs within the evaluation cohort.")
  for (nm in c("split", "model", "feature_set"))
    if (length(unique(as.character(predictions[[nm]]))) != 1L)
      fail(paste("Evaluate exactly one", nm, "per call; mixed groups are not pooled."))
  split <- as.character(predictions$split[1])
  if (!split %in% c("train", "validation", "test")) fail("split must be train, validation or test.")
  if (split == "test" && !allow_test) fail("Test evaluation is locked; set allow_test=TRUE only after model selection is frozen.")
  if (!as.character(predictions$feature_set[1]) %in% c("time_only", "archived_context"))
    fail("feature_set must be time_only or archived_context.")
  truth <- as.character(predictions$true_class)
  predicted <- as.character(predictions$predicted_class)
  if (any(!truth %in% labels) || any(!predicted %in% labels))
    fail("true_class and predicted_class must use exact classes.csv labels, not numeric class IDs.")
  for (nm in c("true_class", "predicted_class"))
    if (is.factor(predictions[[nm]]) && !identical(levels(predictions[[nm]]), labels))
      fail(paste(nm, "factor levels must match all 102 classes in fixed order; character labels are also accepted."))
  if (!is.null(expected_ids)) {
    if (anyNA(expected_ids) || anyDuplicated(as.character(expected_ids)) ||
        !identical(ids, as.character(expected_ids)))
      fail("rdt_id sequence does not match expected_ids exactly (missing, extra or reordered records).")
  }
  if (!is.null(expected_true_class) && !identical(truth, as.character(expected_true_class)))
    fail("true_class does not match expected_true_class in row order.")
  if (!all(vapply(predictions[probability_columns], is.numeric, logical(1))))
    fail("All probability columns must be numeric.")
  probabilities <- as.matrix(predictions[probability_columns])
  if (any(!is.finite(probabilities))) fail("Probabilities contain missing, NaN or infinite values.")
  if (any(probabilities < 0 | probabilities > 1)) fail("Probabilities must lie in [0,1]; values are never clipped.")
  bad <- which(abs(rowSums(probabilities) - 1) > probability_tolerance)
  if (length(bad)) fail(paste("Probability row sums differ from 1; first invalid row:", bad[1]))
  truth_index <- match(truth, labels)
  predicted_index <- match(predicted, labels)
  # A fixed first-maximum tie rule makes class-based metrics consistent.
  argmax <- max.col(probabilities, ties.method = "first")
  if (any(predicted_index != argmax))
    fail("predicted_class must equal the first maximum-probability class in fixed classes.csv order (including ties).")

  confusion <- table(true_class = factor(truth, levels = labels),
                     predicted_class = factor(predicted, levels = labels))
  tp <- as.numeric(diag(confusion))
  support <- as.numeric(rowSums(confusion))
  predicted_support <- as.numeric(colSums(confusion))
  precision <- ifelse(predicted_support > 0, tp / predicted_support, NA_real_)
  recall <- ifelse(support > 0, tp / support, NA_real_)
  # Fixed-label macro-F1 includes all 102 classes. No support/no predictions => 0.
  denominator <- support + predicted_support
  f1 <- ifelse(denominator > 0, 2 * tp / denominator, 0)
  per_class <- data.frame(classes, support = support, predicted_support = predicted_support,
    true_positive = tp, precision = precision, recall = recall, f1 = f1)
  distance <- predicted_index - truth_index
  true_probability <- probabilities[cbind(seq_len(nrow(predictions)), truth_index)]
  # Exact log loss: zero assigned to an observed truth yields +Inf, not clipping.
  log_loss <- -log(true_probability)
  summary <- data.frame(split = split, model = as.character(predictions$model[1]),
    feature_set = as.character(predictions$feature_set[1]), n = nrow(predictions),
    log_loss = mean(log_loss), accuracy = mean(distance == 0), macro_f1 = mean(f1),
    within_one_class_pct = 100 * mean(abs(distance) <= 1),
    underestimation_rate = mean(distance < 0), overestimation_rate = mean(distance > 0),
    observed_classes = sum(support > 0), macro_f1_classes = length(labels))
  ordinal_summary <- function(mask, name) {
    d <- distance[mask]
    data.frame(subset = name, n = length(d),
      accuracy = if (length(d)) mean(d == 0) else NA_real_,
      within_one_class_pct = if (length(d)) 100 * mean(abs(d) <= 1) else NA_real_,
      underestimation_rate = if (length(d)) mean(d < 0) else NA_real_,
      overestimation_rate = if (length(d)) mean(d > 0) else NA_real_)
  }
  terminal <- length(labels)
  ordinal <- rbind(ordinal_summary(rep(TRUE, length(distance)), "all"),
    ordinal_summary(truth_index != terminal & predicted_index != terminal, "both_finite_intervals"),
    ordinal_summary(truth_index == terminal, "true_open_ended"),
    ordinal_summary(truth_index == terminal | predicted_index == terminal, "either_open_ended"))
  per_observation <- data.frame(predictions[metadata_columns], true_probability = true_probability,
    log_loss = log_loss, class_offset = distance, within_one_class = abs(distance) <= 1,
    direction = ifelse(distance < 0, "under", ifelse(distance > 0, "over", "exact")),
    true_open_ended = truth_index == terminal, predicted_open_ended = predicted_index == terminal)
  list(summary = summary, per_class = per_class, confusion_matrix = confusion,
       ordinal_summary = ordinal, per_observation = per_observation,
       classes = classes, settings = list(probability_tolerance = probability_tolerance,
         macro_f1_convention = "All 102 fixed classes; zero undefined F1; recall NA when support is zero.",
         log_loss_convention = "Natural logarithm, no clipping; zero true probability yields Inf.",
         prediction_rule = "First maximum in fixed class order.",
         ordinal_interpretation = "Class positions only; never exact minute errors, especially for 1010_plus.",
         cohort_verified = !is.null(expected_ids), truth_verified = !is.null(expected_true_class),
         classes_md5 = unname(tools::md5sum(classes_path)), R_version = R.version.string))
}
