# Common class-probability diagnostics for old and new models. No test outcomes.
source("moddeling/05_random_forest/tree_workflow.R")
output <- "moddeling/13_survival/output"
d <- prepare_data(include_retrospective_cause = TRUE, include_test_outcomes = FALSE)
stopifnot(all(is.na(d$test$y)), all(is.na(d$test$duration_minutes)))
sources <- data.frame(key = c("global", "cause", "logistic_time", "logistic_context",
 "forest_time", "forest_context", "boosting_time", "boosting_context",
 "survival_time", "survival_context", "survival_recent_time", "survival_recent_context"),
 path = c("03_baselines/output/global", "03_baselines/output/cause",
 "04_logistic_regression/output/time_only", "04_logistic_regression/output/archived_context",
 "05_random_forest/output/time_only", "05_random_forest/output/archived_context",
 "06_gradient_boosting/output/time_only", "06_gradient_boosting/output/archived_context",
 "13_survival/output/time_only", "13_survival/output/archived_context",
 "13_survival/output/time_only_since2017", "13_survival/output/archived_context_since2017"))
truth <- d$validation$class_id + 1L
truth_cdf <- outer(truth, 1:101, `<=`) * 1
dates <- format(parse_utc(d$validation$metadata$start_time), "%Y-%m-%d", tz = "Europe/Amsterdam")
summary <- calibration <- thresholds <- interval_rows <- data.frame()
evaluations <- list()
for (i in seq_len(nrow(sources))) {
 key <- sources$key[i]
 pred <- read.csv(paste0("moddeling/", sources$path[i], "_validation_predictions.csv.gz"), check.names = FALSE)
 e <- evaluate_predictions(pred, expected_ids = d$validation$ids, expected_true_class = d$validation$y)
 p <- as.matrix(pred[d$probability_columns])
 cdf <- t(apply(p, 1, cumsum)); cdf[, 102] <- 1
 rps <- rowMeans((cdf[, 1:101] - truth_cdf)^2)
 lo <- apply(cdf, 1, function(z) which(z >= .1)[1])
 hi <- apply(cdf, 1, function(z) which(z >= .9)[1])
 width <- d$classes$upper_exclusive_minutes[hi] - d$classes$lower_inclusive_minutes[lo]
 covered <- truth >= lo & truth <= hi
 summary <- rbind(summary, cbind(key = key, e$summary, rps = mean(rps),
   central80_class_coverage = mean(covered), mean_interval_class_count = mean(hi - lo + 1L),
   finite_interval_fraction = mean(is.finite(width)),
   mean_finite_interval_width_minutes = if (any(is.finite(width))) mean(width[is.finite(width)]) else NA_real_))
 interval_rows <- rbind(interval_rows, data.frame(key = key, rdt_id = pred$rdt_id,
   lower_class = lo - 1L, upper_class = hi - 1L, lower_minutes = d$classes$lower_inclusive_minutes[lo],
   upper_minutes_exclusive = d$classes$upper_exclusive_minutes[hi], covered = covered))
 for (threshold in c(30L, 60L, 120L)) {
   # Frozen half-open bins identify P(T < threshold), not P(T <= threshold).
   prob <- cdf[, threshold / 10L]
   actual <- as.integer(d$validation$duration_minutes < threshold)
   thresholds <- rbind(thresholds, data.frame(key = key, threshold_minutes_exclusive = threshold,
     n = length(prob), predicted_rate = mean(prob), observed_rate = mean(actual),
     brier_score = mean((prob - actual)^2)))
   bin <- pmin(9L, floor(prob * 10))
   for (b in sort(unique(bin))) {
     m <- bin == b
     calibration <- rbind(calibration, data.frame(key = key, threshold_minutes_exclusive = threshold,
       probability_bin_lower = b / 10, n = sum(m), mean_probability = mean(prob[m]),
       observed_fraction = mean(actual[m]), small_bin = sum(m) < 50))
   }
 }
 evaluations[[key]] <- list(loss = e$per_observation$log_loss, rps = rps,
   feature_set = as.character(e$summary$feature_set), predicted = match(pred$predicted_class, d$class_levels))
}
summary <- summary[order(summary$feature_set, summary$log_loss), ]
write.csv(summary, file.path(output, "all_model_comparison.csv"), row.names = FALSE)
write.csv(thresholds, file.path(output, "operational_thresholds.csv"), row.names = FALSE)
write.csv(calibration, file.path(output, "calibration_bins.csv"), row.names = FALSE)
write_gzip_csv(interval_rows, file.path(output, "central80_intervals.csv.gz"))

# Day-cluster intervals describe uncertainty after development/selection; not
# a fresh confirmatory experiment and not a multiple-comparison correction.
boot <- data.frame()
for (key in sources$key[grepl("survival", sources$key)]) {
 comparator <- if (evaluations[[key]]$feature_set == "time_only") "forest_time" else "forest_context"
 for (metric in c("loss", "rps")) {
   delta <- evaluations[[key]][[metric]] - evaluations[[comparator]][[metric]]
   sums <- tapply(delta, dates, sum); n <- table(factor(dates, levels = names(sums)))
   set.seed(42)
   b <- replicate(500, {idx <- sample.int(length(sums), replace = TRUE); sum(sums[idx]) / sum(n[idx])})
   boot <- rbind(boot, data.frame(key = key, comparator = comparator, metric = metric,
     mean_difference = mean(delta), lower_95 = unname(quantile(b, .025)), upper_95 = unname(quantile(b, .975))))
 }
}
write.csv(boot, file.path(output, "paired_day_bootstrap.csv"), row.names = FALSE)
winner <- do.call(rbind, lapply(c("time_only", "archived_context"), function(f) {
 z <- summary[summary$feature_set == f, ]; z[which.min(z$log_loss), ]
}))
write.csv(winner, file.path(output, "validation_selection_proposal.csv"), row.names = FALSE)

# Error analysis by archived cause and local calendar month, with group support.
path <- "data/disruptions_2011_2025_clean.csv"
header <- names(read.csv(path, nrows = 0))
cc <- setNames(rep("NULL", length(header)), header); cc[c("rdt_id", "cause_group")] <- "character"
meta <- read.csv(path, colClasses = cc)
meta <- meta[match(d$validation$ids, meta$rdt_id), ]
stopifnot(identical(as.character(meta$rdt_id), d$validation$ids))
meta$cause_group[is.na(meta$cause_group) | meta$cause_group == ""] <- "unknown"
meta$month <- substr(dates, 1, 7)
groups <- data.frame()
for (key in c("forest_context", "survival_context", "survival_recent_context")) {
 for (type in c("cause_group", "month")) for (g in sort(unique(meta[[type]]))) {
   mask <- meta[[type]] == g; e <- evaluations[[key]]
   groups <- rbind(groups, data.frame(key = key, group_type = type, group = g, n = sum(mask),
     small_group = sum(mask) < 50, log_loss = mean(e$loss[mask]), rps = mean(e$rps[mask]),
     exact_accuracy = mean(e$predicted[mask] == truth[mask])))
 }
}
write.csv(groups, file.path(output, "subgroup_errors.csv"), row.names = FALSE)

png(file.path(output, "probability_diagnostics.png"), width = 1600, height = 750, res = 140, bg = "white")
par(mfrow = c(1, 2), mar = c(5, 9, 3, 1))
z <- summary[summary$feature_set == "archived_context", ]
labels <- c(forest_context = "Random forest", survival_recent_context = "Survival: 2017 onward",
 survival_context = "Survival: all years", cause = "Cause baseline",
 logistic_context = "Logistic regression", boosting_context = "Multiclass boosting")
plot(z$log_loss, rev(seq_len(nrow(z))), pch = 19, col = "#3478A5", yaxt = "n",
 ylab = "", xlab = "Log loss (lower is better)", main = "2024: archived context",
 xlim = range(z$log_loss) + c(-.004, .004))
axis(2, at = rev(seq_len(nrow(z))), labels = labels[z$key], las = 1, cex.axis = .8)
par(mar = c(5, 4, 3, 1))
plot(c(0, 1), c(0, 1), type = "n", xlab = "Predicted probability", ylab = "Observed fraction",
 main = "Ends before 60 minutes", xaxs = "i", yaxs = "i")
abline(0, 1, col = "grey65", lty = 2)
keys <- c("forest_context", "survival_context", "survival_recent_context")
cols <- c("#3478A5", "#C8622B", "#55854A")
for (j in seq_along(keys)) {
 z <- calibration[calibration$key == keys[j] & calibration$threshold_minutes_exclusive == 60, ]
 lines(z$mean_probability, z$observed_fraction, col = cols[j])
 points(z$mean_probability, z$observed_fraction, col = cols[j], pch = ifelse(z$small_bin, 1, 16))
}
legend("topleft", legend = c(keys, "Open point: fewer than 50"), col = c(cols, "grey40"),
 pch = c(16, 16, 16, 1), cex = .7, bty = "n")
dev.off()
writeLines(c("# Validation selection and uncertainty", "",
 "Development comparison only: 2024 has already informed earlier experiments; 2025 is untouched.",
 "Primary selection: minimum log loss, separately for each feature set. RPS, exact accuracy and calibration are diagnostics.",
 paste("Proposed time-only model:", winner$key[winner$feature_set == "time_only"]),
 paste("Proposed archived-context model:", winner$key[winner$feature_set == "archived_context"]),
 "", "## Full comparison", "", capture.output(print(summary, row.names = FALSE)), "",
 "## Paired day bootstrap", "", capture.output(print(boot, row.names = FALSE)), "",
 "Central 80% intervals include entire boundary bins, so discrete coverage can exceed 80% even for a calibrated model.",
 "Finite widths exclude open-ended intervals; interpret alongside finite_interval_fraction. No midpoint for the final class.",
 "These are model-based intervals, not calibrated/conformal guarantees. Calibration is assessed, not fitted on 2024.",
 "Archived causes/locations may be revised. Outcome-selected <=24-hour archive limits generalization.",
 "Survival formulation does not repair selection bias or reconstruct missing censored incidents.",
 "Recent-period sensitivity uses fixed full-history settings and refitted preprocessing; it is not a fully retuned comparison.",
 "All twelve prediction tables passed the unchanged evaluator with identical IDs, classes and labels."),
 file.path(output, "selection_and_uncertainty.md"))
print(summary[, c("key", "log_loss", "accuracy", "rps", "central80_class_coverage")]); print(boot)
