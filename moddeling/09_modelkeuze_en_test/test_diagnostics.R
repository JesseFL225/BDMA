# Called after final_test.R has opened outcomes. No fitting or model selection.
summary <- thresholds <- calibration <- intervals <- groups <- bootstrap <- data.frame()
index <- truth$test$class_id + 1L
observed_cdf <- outer(index, 1:101, `<=`) * 1
dates <- format(parse_utc(truth$test$metadata$start_time), "%Y-%m-%d", tz = "Europe/Amsterdam")
header <- names(read.csv("data/disruptions_2011_2025_clean.csv", nrows = 0))
cc <- setNames(rep("NULL", length(header)), header); cc[c("rdt_id", "cause_group")] <- "character"
meta <- read.csv("data/disruptions_2011_2025_clean.csv", colClasses = cc)
meta <- meta[match(truth$test$ids, meta$rdt_id), ]
stopifnot(identical(as.character(meta$rdt_id), truth$test$ids))
meta$cause_group[is.na(meta$cause_group) | meta$cause_group == ""] <- "unknown"
meta$month <- substr(dates, 1, 7)
for (key in names(evaluations)) {
 p <- forecast[[key]]; e <- evaluations[[key]]
 cdf <- t(apply(p, 1, cumsum)); cdf[, 102] <- 1
 rps <- rowMeans((cdf[, 1:101] - observed_cdf)^2)
 lo <- apply(cdf, 1, function(x) which(x >= .1)[1])
 hi <- apply(cdf, 1, function(x) which(x >= .9)[1])
 width <- truth$classes$upper_exclusive_minutes[hi] - truth$classes$lower_inclusive_minutes[lo]
 covered <- index >= lo & index <= hi
 summary <- rbind(summary, cbind(key = key, e$summary, rps = mean(rps),
   central80_coverage = mean(covered), finite_interval_fraction = mean(is.finite(width)),
   mean_finite_width_minutes = mean(width[is.finite(width)])))
 intervals <- rbind(intervals, data.frame(key = key, rdt_id = truth$test$ids,
   lower_minutes = truth$classes$lower_inclusive_minutes[lo],
   upper_minutes_exclusive = truth$classes$upper_exclusive_minutes[hi], covered = covered))
 for (t in c(30L, 60L, 120L)) {
   prob <- cdf[, t / 10]; actual <- as.integer(truth$test$duration_minutes < t)
   thresholds <- rbind(thresholds, data.frame(key = key, threshold_minutes_exclusive = t,
     n = length(prob), predicted_rate = mean(prob), observed_rate = mean(actual), brier_score = mean((prob - actual)^2)))
   bin <- pmin(9L, floor(prob * 10))
   for (b in sort(unique(bin))) {
     m <- bin == b
     calibration <- rbind(calibration, data.frame(key = key, threshold_minutes_exclusive = t,
       probability_bin_lower = b / 10, n = sum(m), mean_probability = mean(prob[m]),
       observed_fraction = mean(actual[m]), small_bin = sum(m) < 50))
   }
 }
 for (type in c("cause_group", "month")) for (g in sort(unique(meta[[type]]))) {
   m <- meta[[type]] == g
   groups <- rbind(groups, data.frame(key = key, group_type = type, group = g,
     n = sum(m), small_group = sum(m) < 50, log_loss = mean(e$per_observation$log_loss[m]),
     accuracy = mean(e$per_observation$class_offset[m] == 0), rps = mean(rps[m])))
 }
}
for (key in plan$key) {
 delta <- evaluations[[key]]$per_observation$log_loss - evaluations[[paste0(key, "_baseline")]]$per_observation$log_loss
 sums <- tapply(delta, dates, sum); n <- table(factor(dates, levels = names(sums)))
 set.seed(42)
 b <- replicate(500, {j <- sample.int(length(sums), replace = TRUE); sum(sums[j]) / sum(n[j])})
 bootstrap <- rbind(bootstrap, data.frame(key = key, comparator = paste0(key, "_baseline"),
   mean_log_loss_difference = mean(delta), lower_95 = unname(quantile(b, .025)), upper_95 = unname(quantile(b, .975)),
   replicates = 500, days = length(sums)))
}
for (nm in c("summary", "thresholds", "calibration", "groups", "bootstrap"))
 write.csv(get(nm), file.path(output, paste0("test_", nm, ".csv")), row.names = FALSE)
write_gzip_csv(intervals, file.path(output, "test_central80_intervals.csv.gz"))
validation <- read.csv("moddeling/13_survival/output/all_model_comparison.csv")
comparison <- merge(validation[validation$key %in% plan$key, c("key", "log_loss", "accuracy", "rps")],
 summary[summary$key %in% plan$key, c("key", "log_loss", "accuracy", "rps")], by = "key", suffixes = c("_2024", "_2025"))
write.csv(comparison, file.path(output, "validation_to_test.csv"), row.names = FALSE)
table_lines <- c("| Model | Test n | Log loss | Exact accuracy | RPS |", "|---|---:|---:|---:|---:|",
 vapply(seq_len(nrow(summary)), function(i) sprintf("| %s | %d | %.4f | %.2f%% | %.5f |",
   summary$key[i], summary$n[i], summary$log_loss[i], 100 * summary$accuracy[i], summary$rps[i]), character(1)))
writeLines(c("# Final 2025 test — frozen-model results", "",
 "Model choices and diagnostics were fixed before opening 2025 outcomes, following user authorization on 13 November 2026.",
 "No model was refitted on 2024 or 2025. Existing fitted models and reconstructed training preprocessing were used.", "",
 table_lines, "", "## Paired comparison with matched baseline", "",
 capture.output(print(bootstrap, row.names = FALSE)), "", "## Validation versus test", "",
 capture.output(print(comparison, row.names = FALSE)), "", "## Interpretation and limits", "",
 "Negative log-loss differences favour the selected model. Baselines use the matching training years and information set.",
 "Time-only and archived-context results are separate experiments; context includes potentially revised causes/locations.",
 "Lower test loss than validation does not establish drift improvement: annual populations differ.",
 "An 80% central class interval includes entire edge bins; observed coverage need not equal 80%.",
 "Width summaries exclude infinite upper bounds and must be read with finite_interval_fraction. No guaranteed coverage.",
 "The data exclude durations over 24 hours and other outcome-selected records. Results apply to that selected population.",
 "Do not tune or choose a replacement using these test results. Later development needs a new holdout for a fresh final test.",
 "", "See test_thresholds.csv, test_calibration.csv and test_groups.csv for probability diagnostics and supported subgroup errors."),
 file.path(output, "FINAL_TEST_REPORT.md"))
print(summary[, c("key", "n", "log_loss", "accuracy", "rps", "central80_coverage", "mean_finite_width_minutes")])
print(bootstrap)
