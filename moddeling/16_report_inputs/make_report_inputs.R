# =============================================================================
# Step 16 — Report inputs: every table and figure the Part B report needs
# =============================================================================
# Purpose
#   Turn the saved results of Steps 01–13 and the frozen 2025 test (Step 09)
#   into report-ready tables and figures, in the order of the report sections.
#   This is the "walkthrough" a reader can run to reproduce every number.
#
# What this script does NOT do
#   - It fits no model and changes no model choice.
#   - It only READS the saved 2025 predictions of the frozen models. The extra
#     diagnostics computed here (AUC, decision-level rates) are additional
#     evaluation of already-frozen models, not model selection.
#
# Inputs (all read-only)
#   data/disruptions_2011_2025_clean.csv
#   Data Cleaning/output/yearly_profile.csv
#   moddeling/13_survival/output/all_model_comparison.csv        (validation 2024)
#   moddeling/09_modelkeuze_en_test/output/test_*.csv             (test 2025)
#   moddeling/09_modelkeuze_en_test/output/*_test_predictions.csv.gz
#
# Outputs (moddeling/16_report_inputs/output/)
#   fig1_duration_distribution.png   fig2_yearly_shift.png
#   fig3_validation_comparison.png   fig4_test_gain_over_baseline.png
#   fig5_information_vs_algorithm.png fig6_calibration_60min.png
#   table1_feature_dictionary.csv     table2_cause_groups.csv
#   table3_validation_models.csv      table4_test_results.csv
#   table5_test_decision_level.csv    checks.csv
#
# Run from the repository root:  Rscript moddeling/16_report_inputs/make_report_inputs.R
# Base R only. Runs in well under a minute.
# =============================================================================

out_dir <- "moddeling/16_report_inputs/output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
test_dir <- "moddeling/09_modelkeuze_en_test/output"

# ---- Shared chart style ------------------------------------------------------
# Two categorical colours, validated for colour-vision deficiency and contrast
# (dataviz palette slots 1 and 2): blue = time-only scenario, orange = context.
# Baselines are drawn as hollow markers, models as filled markers, so identity
# never depends on colour alone.
col_time    <- "#2a78d6"
col_context <- "#eb6834"
ink         <- "#0b0b0b"   # primary text
ink_soft    <- "#52514e"   # secondary text, axes
grid_col    <- "#e4e3df"   # recessive grid lines

open_png <- function(name, width = 1800, height = 1050) {
  png(file.path(out_dir, name), width = width, height = height, res = 200, bg = "#fcfcfb")
  par(family = "sans", col.axis = ink_soft, col.lab = ink, col.main = ink, fg = ink_soft,
      cex.main = 1.05, font.main = 2, las = 1, mgp = c(2.4, 0.6, 0), tcl = -0.25)
}
fmt <- function(x, digits = 4) formatC(x, format = "f", digits = digits)
pct <- function(x, digits = 1) paste0(formatC(100 * x, format = "f", digits = digits), "%")
write_table <- function(d, name) write.csv(d, file.path(out_dir, name), row.names = FALSE)
checks <- data.frame(check = character(), passed = logical())
add_check <- function(label, ok) checks[nrow(checks) + 1, ] <<- list(label, isTRUE(ok))

# =============================================================================
# Report section 2 — Data description: feature dictionary
# =============================================================================
# The models never see the raw columns directly; Step 02 turns them into the
# features below. Duration, end time and statistical cause are never features.
feature_dictionary <- data.frame(
  feature_set = c(rep("time_only (and archived_context)", 5), rep("archived_context only", 7)),
  feature = c("hour_X0 … hour_X23", "weekday_X1 … weekday_X7", "month_X1 … month_X12",
              "weekend", "rush_hour",
              "cause_group_* (incl. __MISSING__, __UNSEEN__)", "cause_missing",
              "route_count", "station_count", "routes_missing / stations_missing",
              "hub_* (5 hubs)", "route_X* (20 routes)"),
  source_column = c("start_time", "start_time", "start_time", "start_time", "start_time",
                    "cause_group", "cause_group / cause_nl", "rdt_lines_id", "rdt_station_codes",
                    "rdt_lines_id / rdt_station_codes", "rdt_station_codes", "rdt_lines_id"),
  meaning = c(
    "Local start hour (Europe/Amsterdam), one-hot",
    "Local weekday, Monday = 1, one-hot",
    "Local month, one-hot",
    "1 if Saturday or Sunday",
    "1 on weekdays 07:00–09:00 and 16:00–19:00",
    "Broad cause category as finally recorded (retrospective), one-hot; categories learned on training",
    "1 if the cause is missing or 'unknown'",
    "Number of affected routes (median-imputed if missing, standardised)",
    "Number of affected stations (median-imputed if missing, standardised)",
    "1 if no route / station information is recorded",
    "1 if Amsterdam C., Utrecht C., Rotterdam C., Schiphol Airport or Den Haag C. is affected",
    "1 if one of the 20 most frequent training routes is affected (multi-hot)"),
  known_at_onset = c(rep("yes", 5), rep("not guaranteed: may be revised after onset", 7)))
write_table(feature_dictionary, "table1_feature_dictionary.csv")

# =============================================================================
# Report section 4 — Descriptive analysis of the clean data
# =============================================================================
clean <- read.csv("data/disruptions_2011_2025_clean.csv", stringsAsFactors = FALSE)
duration <- clean$duration_minutes
add_check("Clean data has 44,248 rows", nrow(clean) == 44248)

# Figure 1: duration distribution in 10-minute bins (the target classes).
# Shown up to 300 minutes; the long tail is summarised in the subtitle.
open_png("fig1_duration_distribution.png")
par(mar = c(4.2, 5.2, 3.6, 1), mgp = c(3.4, 0.6, 0))
breaks <- seq(0, 300, by = 10)
shown <- duration[duration < 300]
h <- hist(shown, breaks = breaks, plot = FALSE)
plot(NA, xlim = c(0, 300), ylim = c(0, max(h$counts) * 1.08), xaxs = "i", yaxs = "i",
     xlab = "Disruption duration (minutes); each bar = one 10-minute target class",
     ylab = "Number of disruptions", axes = FALSE,
     main = "Most disruptions are short, but the tail is long")
abline(h = pretty(c(0, max(h$counts))), col = grid_col, lwd = 1)
rect(h$breaks[-length(h$breaks)] + 0.6, 0, h$breaks[-1] - 0.6, h$counts, col = col_time, border = NA)
abline(v = 60, col = ink_soft, lty = 2, lwd = 1.5)
text(62, max(h$counts) * 1.0, "60 min", adj = 0, col = ink_soft, cex = 0.8)
axis(1, at = seq(0, 300, 30)); axis(2)
mtext(sprintf("Median %d min · %s over 60 min · %s over 300 min (not shown) · %s in the final class (≥ 1010 min)",
              as.integer(median(duration)), pct(mean(duration > 60)), pct(mean(duration >= 300)),
              pct(mean(duration >= 1010), 2)), side = 3, line = 0.3, cex = 0.75, col = ink_soft)
dev.off()

# Figure 2: how the data differ by year (two panels, never a dual axis).
yearly <- read.csv("Data Cleaning/output/yearly_profile.csv")
open_png("fig2_yearly_shift.png", width = 2000, height = 950)
par(mfrow = c(1, 2), mar = c(4, 4.6, 3.4, 1))
panel_years <- function(y, ylab, title, ylim) {
  plot(NA, xlim = range(yearly$year) + c(-0.5, 0.5), ylim = ylim, xlab = "Start year",
       ylab = ylab, main = title, axes = FALSE)
  abline(h = pretty(ylim), col = grid_col)
  rect(2010.5, ylim[1], 2016.5, ylim[2], col = "#f1f0ed", border = NA)
  text(2013.5, ylim[2] * 0.97, "2011–2016", col = ink_soft, cex = 0.75)
  lines(yearly$year, y, col = col_time, lwd = 2)
  points(yearly$year, y, pch = 21, bg = col_time, col = "#fcfcfb", cex = 1.3, lwd = 1.5)
  axis(1, at = seq(2011, 2025, 2)); axis(2)
}
panel_years(yearly$retained_pct, "% of raw records kept", "Share kept after cleaning", c(0, 100))
panel_years(yearly$median_duration_min, "Median duration (minutes)", "Median duration of kept disruptions", c(0, 170))
dev.off()

# Table 2: cause groups in the clean data (all years) — size and duration.
cause_table <- do.call(rbind, lapply(split(clean, clean$cause_group), function(d) data.frame(
  cause_group = d$cause_group[1], n = nrow(d), share = round(nrow(d) / nrow(clean), 4),
  median_duration_min = median(d$duration_minutes),
  share_over_60_min = round(mean(d$duration_minutes > 60), 4))))
cause_table <- cause_table[order(-cause_table$n), ]
write_table(cause_table, "table2_cause_groups.csv")

# =============================================================================
# Report section 5 — Validation 2024: all model families
# =============================================================================
validation <- read.csv("moddeling/13_survival/output/all_model_comparison.csv")
validation <- validation[validation$split == "validation", ]
labels <- c(global = "Global frequency baseline", cause = "Cause-group baseline",
            logistic_time = "Logistic regression", logistic_context = "Logistic regression",
            forest_time = "Random forest", forest_context = "Random forest",
            boosting_time = "Multiclass XGBoost", boosting_context = "Multiclass XGBoost",
            survival_time = "Survival, 2011–2023", survival_context = "Survival, 2011–2023",
            survival_recent_time = "Survival, 2017–2023", survival_recent_context = "Survival, 2017–2023")
validation$model_label <- labels[validation$key]
baseline_loss <- c(time_only = validation$log_loss[validation$key == "global"],
                   archived_context = validation$log_loss[validation$key == "cause"])
validation$gain_over_baseline <- baseline_loss[validation$feature_set] - validation$log_loss
table3 <- data.frame(feature_set = validation$feature_set, model = validation$model_label,
  log_loss = round(validation$log_loss, 4), gain_over_baseline = round(validation$gain_over_baseline, 4),
  exact_class = round(validation$accuracy, 4), within_one_class = round(validation$within_one_class_pct / 100, 4),
  rps = round(validation$rps, 5))
table3 <- table3[order(table3$feature_set != "time_only", table3$log_loss), ]
write_table(table3, "table3_validation_models.csv")
add_check("Validation table has 12 model rows (6 per feature set)", nrow(table3) == 12)

# Figure 3: gain over the scenario's own baseline (positive = better).
# Plotting the gain instead of raw log loss avoids bars that all look equal.
open_png("fig3_validation_comparison.png", width = 2000, height = 1050)
par(mfrow = c(1, 2), mar = c(4.2, 10.5, 3.4, 1))
panel_gain <- function(fs, colour, title) {
  d <- validation[validation$feature_set == fs & !validation$key %in% c("global", "cause"), ]
  d <- d[order(d$gain_over_baseline), ]
  xlim <- c(min(0, d$gain_over_baseline) - 0.008, max(d$gain_over_baseline) + 0.010)
  plot(NA, xlim = xlim, ylim = c(0.5, nrow(d) + 0.5), axes = FALSE, xlab = "Gain over baseline (higher = better)",
       ylab = "", main = title)
  abline(v = pretty(xlim), col = grid_col); abline(v = 0, col = ink_soft, lwd = 1.5)
  segments(0, seq_len(nrow(d)), d$gain_over_baseline, seq_len(nrow(d)), col = colour, lwd = 2)
  points(d$gain_over_baseline, seq_len(nrow(d)), pch = 21, bg = colour, col = "#fcfcfb", cex = 1.5, lwd = 1.5)
  # Value labels sit on the outer side of each dot so they never cover the bar.
  text(d$gain_over_baseline, seq_len(nrow(d)), fmt(d$gain_over_baseline, 4),
       pos = ifelse(d$gain_over_baseline < 0, 2, 4), cex = 0.7, col = ink)
  axis(1, at = pretty(xlim, n = 5), labels = fmt(pretty(xlim, n = 5), 2), cex.axis = 0.85)
  axis(2, at = seq_len(nrow(d)), labels = d$model_label, tick = FALSE, cex.axis = 0.85)
  mtext("0 = baseline", side = 3, line = 0.2, adj = 0, cex = 0.7, col = ink_soft)
}
panel_gain("time_only", col_time, "Time-only (validation 2024)")
panel_gain("archived_context", col_context, "Archived context (validation 2024)")
dev.off()

# =============================================================================
# Report section 5 — Final test 2025 (frozen models, opened once)
# =============================================================================
summary_test <- read.csv(file.path(test_dir, "test_summary.csv"))
bootstrap <- read.csv(file.path(test_dir, "test_bootstrap.csv"))
thresholds <- read.csv(file.path(test_dir, "test_thresholds.csv"))
calibration <- read.csv(file.path(test_dir, "test_calibration.csv"))
models <- c("survival_recent_time_baseline", "survival_recent_time", "forest_context_baseline", "forest_context")
model_names <- c(survival_recent_time_baseline = "Global frequency baseline (2017–2023)",
                 survival_recent_time = "Survival model (2017–2023)",
                 forest_context_baseline = "Cause-group baseline (2011–2023)",
                 forest_context = "Random forest (2011–2023)")
scenario <- c(survival_recent_time_baseline = "time_only", survival_recent_time = "time_only",
              forest_context_baseline = "archived_context", forest_context = "archived_context")

# Decision-level diagnostics from the saved per-row probabilities.
# P(ends before T minutes) = sum of the probabilities of the classes below T.
# AUC = probability that a disruption which ended before T received a higher
# P(ends before T) than one that did not (0.5 = no ranking ability).
auc <- function(score, positive) {
  r <- rank(score); n1 <- sum(positive); n0 <- sum(!positive)
  (sum(r[positive]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
decision_rows <- list()
for (m in models) {
  pred <- read.csv(gzfile(file.path(test_dir, paste0(m, "_test_predictions.csv.gz"))),
                   stringsAsFactors = FALSE, check.names = FALSE)
  prob_cols <- grep("^p_", names(pred), value = TRUE)
  stopifnot(length(prob_cols) == 102)
  true_index <- match(paste0("p_", pred$true_class), prob_cols)
  stopifnot(!anyNA(true_index), nrow(pred) == 5948)
  probs <- as.matrix(pred[, prob_cols])
  for (minutes in c(30, 60, 120)) {
    k <- minutes / 10                       # classes 1..k cover [0, minutes)
    p_before <- rowSums(probs[, seq_len(k), drop = FALSE])
    ended_before <- true_index <= k
    brier <- mean((p_before - ended_before)^2)
    saved <- thresholds$brier_score[thresholds$key == m & thresholds$threshold_minutes_exclusive == minutes]
    add_check(sprintf("Brier %s <%d min reproduces Step 09", m, minutes), abs(brier - saved) < 1e-9)
    decision_rows[[length(decision_rows) + 1]] <- data.frame(
      key = m, model = model_names[[m]], feature_set = scenario[[m]], threshold_minutes = minutes,
      predicted_rate = round(mean(p_before), 4), observed_rate = round(mean(ended_before), 4),
      brier_score = round(brier, 4), auc = round(auc(p_before, ended_before), 4),
      sd_of_predicted_probability = round(sd(p_before), 4))
  }
  log_loss <- -mean(log(probs[cbind(seq_len(nrow(probs)), true_index)]))
  add_check(sprintf("Log loss %s reproduces Step 09", m),
            abs(log_loss - summary_test$log_loss[summary_test$key == m]) < 1e-9)
}
decision <- do.call(rbind, decision_rows)
write_table(decision, "table5_test_decision_level.csv")

# Table 4: overall test results with an intuitive translation of log loss.
# exp(-log loss) = geometric-mean probability given to what actually happened.
# A uniform guess over 102 classes would give 1/102 = 0.98%.
s <- summary_test[match(models, summary_test$key), ]
baseline_of <- c(survival_recent_time = "survival_recent_time_baseline", forest_context = "forest_context_baseline")
gain <- sapply(models, function(m) if (m %in% names(baseline_of))
  s$log_loss[s$key == baseline_of[[m]]] - s$log_loss[s$key == m] else NA)
boot <- bootstrap[match(models, bootstrap$key), ]
table4 <- data.frame(model = model_names[models], feature_set = scenario[models],
  log_loss = round(s$log_loss, 4),
  prob_on_true_class_geomean = round(exp(-s$log_loss), 4),
  gain_over_baseline = round(gain, 4),
  gain_95ci_low = round(-boot$upper_95, 4), gain_95ci_high = round(-boot$lower_95, 4),
  relative_prob_increase_vs_baseline = round(exp(gain) - 1, 4),
  exact_class = round(s$accuracy, 4), within_one_class = round(s$within_one_class_pct / 100, 4),
  underestimation_rate = round(s$underestimation_rate, 4), rps = round(s$rps, 5),
  central80_coverage = round(s$central80_coverage, 4),
  mean_finite_80pct_width_min = round(s$mean_finite_width_minutes, 1))
write_table(table4, "table4_test_results.csv")

# Figure 4: test gain over the matched baseline with 95% day-bootstrap interval.
open_png("fig4_test_gain_over_baseline.png", width = 1800, height = 800)
par(mar = c(4.2, 14, 3.4, 1.5))
rows <- c("forest_context", "survival_recent_time")
g <- -bootstrap$mean_log_loss_difference[match(rows, bootstrap$key)]
lo <- -bootstrap$upper_95[match(rows, bootstrap$key)]; hi <- -bootstrap$lower_95[match(rows, bootstrap$key)]
cols <- c(col_context, col_time)
plot(NA, xlim = c(-0.005, 0.115), ylim = c(0.5, 2.5), axes = FALSE, ylab = "",
     xlab = "Log-loss gain over matched baseline (higher = better)",
     main = "Final test 2025: both frozen models beat their baseline")
abline(v = seq(0, 0.07, 0.01), col = grid_col); abline(v = 0, col = ink_soft, lwd = 1.5)
segments(lo, 1:2, hi, 1:2, col = cols, lwd = 3)
points(g, 1:2, pch = 21, bg = cols, col = "#fcfcfb", cex = 1.8, lwd = 1.5)
text(hi, 1:2, sprintf("%s  (95%% CI %s to %s)", fmt(g), fmt(lo), fmt(hi)), pos = 4, cex = 0.75, col = ink)
axis(1, at = seq(0, 0.10, 0.02)); axis(2, at = 1:2, tick = FALSE, cex.axis = 0.85,
              labels = c("Random forest vs cause baseline\n(archived context)", "Survival vs global baseline\n(time-only)"))
mtext("Interval: 500 resamples of calendar days. 0 = no improvement.", side = 3, line = 0.2, adj = 0, cex = 0.7, col = ink_soft)
dev.off()

# Figure 5: information versus algorithm — decision-level Brier score and AUC.
open_png("fig5_information_vs_algorithm.png", width = 2000, height = 1100)
par(mfrow = c(1, 2), mar = c(4.2, 4.6, 3.6, 1), oma = c(2.4, 0, 0, 0))
panel_decision <- function(metric, ylab, title, ylim, ref = NULL) {
  plot(NA, xlim = c(0.6, 3.4), ylim = ylim, axes = FALSE, xlab = "Question: does the disruption end before …",
       ylab = ylab, main = title)
  abline(h = pretty(ylim), col = grid_col)
  if (!is.null(ref)) { abline(h = ref, col = ink_soft, lty = 2); text(1.5, ref, "0.5 = no ranking ability", adj = c(0.5, 1.6), cex = 0.7, col = ink_soft) }
  offsets <- c(survival_recent_time_baseline = -0.18, survival_recent_time = -0.06,
               forest_context_baseline = 0.06, forest_context = 0.18)
  for (m in models) {
    d <- decision[decision$key == m, ]
    colour <- if (scenario[[m]] == "time_only") col_time else col_context
    filled <- !grepl("baseline", m)
    points(seq_along(d$threshold_minutes) + offsets[[m]], d[[metric]], pch = if (filled) 21 else 1,
           bg = if (filled) colour else NA, col = colour, cex = 1.6, lwd = 2)
  }
  axis(1, at = 1:3, labels = c("30 min", "60 min", "120 min")); axis(2)
}
panel_decision("brier_score", "Brier score (lower = better)", "Prediction error", c(0.12, 0.26))
panel_decision("auc", "AUC (higher = better)", "Ranking short vs long disruptions", c(0.45, 0.85), ref = 0.5)
# Shared legend in the bottom outer margin, so it never covers data.
par(fig = c(0, 1, 0, 1), oma = c(0, 0, 0, 0), mar = c(0, 0, 0, 0), new = TRUE)
plot(0, 0, type = "n", axes = FALSE, xlab = "", ylab = "")
legend("bottom", horiz = TRUE, bty = "n", cex = 0.72, pt.cex = 1.3, pt.lwd = 2, xpd = NA, inset = 0.005,
       legend = c("Time-only: global baseline", "Time-only: survival model",
                  "Context: cause baseline", "Context: random forest"),
       pch = c(1, 21, 1, 21), col = c(col_time, col_time, col_context, col_context),
       pt.bg = c(NA, col_time, NA, col_context), text.col = ink)
dev.off()

# Figure 6: calibration of P(ends before 60 min) for the two frozen models.
open_png("fig6_calibration_60min.png", width = 1300, height = 1200)
par(mar = c(4.4, 4.6, 3.6, 1))
plot(NA, xlim = c(0, 1), ylim = c(0, 1), xaxs = "i", yaxs = "i", asp = 1, axes = FALSE,
     xlab = "Predicted probability of ending before 60 min", ylab = "Observed share that ended before 60 min",
     main = "Test 2025: are the probabilities honest?")
abline(h = seq(0, 1, 0.2), v = seq(0, 1, 0.2), col = grid_col)
abline(0, 1, col = ink_soft, lty = 2)
for (m in c("survival_recent_time", "forest_context")) {
  d <- calibration[calibration$key == m & calibration$threshold_minutes_exclusive == 60, ]
  colour <- if (m == "forest_context") col_context else col_time
  # Only bins with at least 50 cases are connected; small bins are shown hollow
  # and unconnected, because their observed share is too noisy to trace.
  big <- d[!d$small_bin, ]
  lines(big$mean_probability, big$observed_fraction, col = colour, lwd = 2)
  points(d$mean_probability, d$observed_fraction, pch = ifelse(d$small_bin, 1, 21),
         bg = colour, col = colour, cex = 0.8 + 2.2 * sqrt(d$n / max(d$n)), lwd = 1.5)
}
axis(1); axis(2)
legend("topleft", bty = "n", cex = 0.75, text.col = ink, pt.cex = 1.3,
       legend = c("Random forest (context)", "Survival model (time-only)", "Hollow: bin with < 50 cases", "Marker size = number of cases"),
       pch = c(21, 21, 1, NA), col = c(col_context, col_time, ink_soft, NA), pt.bg = c(col_context, col_time, NA, NA))
dev.off()

write_table(checks, "checks.csv")
if (!all(checks$passed)) stop("Some checks failed: see checks.csv")
cat("Report inputs written to", out_dir, "-", nrow(checks), "checks passed\n")
