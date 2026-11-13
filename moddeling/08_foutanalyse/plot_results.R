# Re-render figures from saved outputs; no model fitting or outcome import.
output <- "moddeling/08_foutanalyse/output"
comparison <- read.csv(file.path(output, "validation_comparison.csv"))
imp_summary <- read.csv(file.path(output, "permutation_summary.csv"))
selected <- read.csv(file.path(output, "validation_selection_proposal.csv"))
# Presentation-ready static figures; all model comparison values are validation.
palette <- c("#54738A", "#9BAAB5", "#268B81", "#D88343")
short_name <- function(key) c(global = "Global baseline", cause = "Cause baseline",
 logistic_time = "Logistic regression", logistic_context = "Logistic regression",
 forest_time = "Random forest", forest_context = "Random forest",
 boosting_time = "Gradient boosting", boosting_context = "Gradient boosting")[key]
png(file.path(output, "validation_model_comparison.png"), 1500, 850, res = 140)
par(mfrow = c(1, 2), mar = c(5, 10, 4, 1), family = "sans")
for (f in c("time_only", "archived_context")) {
  z <- comparison[comparison$feature_set == f, ]; z <- z[order(z$log_loss, decreasing = TRUE), ]
  pos <- barplot(z$log_loss, horiz = TRUE, names.arg = short_name(z$key), las = 1,
    col = palette[seq_len(nrow(z))], border = NA, xlim = c(0, max(z$log_loss) * 1.05),
    xlab = "Multiclass log loss (lower is better)",
    main = if (f == "time_only") "Time-only: 2024" else "Archived context: 2024")
  text(z$log_loss - 0.04, pos, sprintf("%.3f", z$log_loss), pos = 2, cex = .8, col = "white", font = 2)
}
dev.off()
png(file.path(output, "validation_error_direction.png"), 1600, 900, res = 140)
par(mar = c(5, 15, 6, 2))
z <- comparison[order(comparison$feature_set, comparison$log_loss, decreasing = TRUE), ]
rates <- rbind(z$underestimation_rate, z$accuracy, z$overestimation_rate) * 100
barplot(rates, horiz = TRUE, border = NA, las = 1, col = c("#CE8153", "#2A8B80", "#6E90B5"),
 names.arg = paste(short_name(z$key), ifelse(z$feature_set == "time_only", "(time)", "(context)")),
 xlab = "Percentage of 2024 validation disruptions", main = "Most errors underestimate the duration class",
 xlim = c(0, 100))
legend("top", inset = c(0, -0.09), xpd = NA, horiz = TRUE, c("Underestimated", "Exact class", "Overestimated"),
 fill = c("#CE8153", "#2A8B80", "#6E90B5"), bty = "n", cex = .8)
dev.off()
png(file.path(output, "grouped_permutation_importance.png"), 1600, 850, res = 140)
par(mfrow = c(1, 2), mar = c(5, 11, 4, 2))
for (f in c("time_only", "archived_context")) {
  z <- imp_summary[imp_summary$feature_set == f, ]; z <- z[order(z$mean_log_loss_increase), ]
  names <- c(time_of_week = "Hour / weekday / rush", month = "Month",
    route_station_context = "Routes / stations / hubs", cause = "Archived cause")
  upper <- max(.01, z$mean_log_loss_increase + z$sd_log_loss_increase)
  lower <- min(0, z$mean_log_loss_increase - z$sd_log_loss_increase)
  pos <- barplot(z$mean_log_loss_increase, horiz = TRUE, names.arg = names[z$group], las = 1,
    col = "#268B81", border = NA, xlim = c(lower * 1.2, upper * 1.2),
    xlab = "Increase in log loss after permutation", main = paste("Best tree:", f))
  segments(z$mean_log_loss_increase - z$sd_log_loss_increase, pos,
    z$mean_log_loss_increase + z$sd_log_loss_increase, pos)
  abline(v = 0, col = "#444444")
}
dev.off()

winner <- selected[selected$feature_set == "archived_context", ]
confusion_paths <- c(
  forest_context = "05_random_forest/output/archived_context_confusion_matrix.csv",
  boosting_context = "06_gradient_boosting/output/archived_context_confusion_matrix.csv",
  logistic_context = "04_logistic_regression/output/archived_context_confusion_matrix.csv",
  cause = "03_baselines/output/cause_confusion_matrix.csv")
stopifnot(winner$key %in% names(confusion_paths))
conf <- as.matrix(read.csv(file.path("moddeling", confusion_paths[[winner$key]]),
  row.names = 1, check.names = FALSE))
png(file.path(output, "selected_context_confusion_matrix.png"), 1300, 1100, res = 140)
par(mar = c(6, 6, 4, 2))
normalised <- conf / pmax(rowSums(conf), 1)
image(0:101, 0:101, t(normalised), zlim = c(0, 1), col = colorRampPalette(c("#F4F7F8", "#126C67"))(100),
 xlab = "Predicted class index", ylab = "True class index", main = "Validation confusion matrix (row-normalised)")
abline(0, 1, lty = 2, col = "#D88343")
mtext("Colour: within-class fraction, from 0 (light) to 1 (dark).", side = 3, line = .4, cex = .8)
mtext("Class 101 is >=1010 minutes; classes without support are blank.", side = 1, line = 4, cex = .8)
dev.off()
