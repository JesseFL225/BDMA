# Run from repository root:
# Rscript "moddeling/01_target/define_duration_classes.R"
# Select the cutoff using TRAINING DATA ONLY. No model is fitted here.
input <- "data/disruptions_2011_2025_clean.csv"
output <- "moddeling/01_target/output"
data <- read.csv(input, na.strings = c("", "NA"))
train <- data[data$start_year >= 2011 & data$start_year <= 2023, ]
d <- train$duration_minutes
stopifnot(length(d) > 0, all(is.finite(d)), all(d > 0))

# Objective: remaining >=cutoff class closest in size to the arithmetic mean
# of ALL preceding 10-minute classes, including any empty classes.
# This balances the tail against the mean, not all classes against each other.
cutoffs <- seq(10, ceiling(max(d) / 10) * 10, by = 10)
candidates <- do.call(rbind, lapply(cutoffs, function(cutoff) {
  counts <- tabulate(floor(d[d < cutoff] / 10) + 1L, nbins = cutoff / 10)
  tail <- sum(d >= cutoff)
  data.frame(cutoff_minutes = cutoff, tail_count = tail,
    mean_regular_count = mean(counts), median_regular_count = median(counts),
    min_regular_count = min(counts), absolute_gap = abs(tail - mean(counts)))
}))
# In a tie choose the smaller cutoff (fewer classes).
chosen <- candidates[order(candidates$absolute_gap, candidates$cutoff_minutes)[1], ]
cutoff <- chosen$cutoff_minutes
lower <- seq(0, cutoff, by = 10)
labels <- c(sprintf("%04d_%04d", head(lower, -1), tail(lower, -1)),
            sprintf("%04d_plus", cutoff))
definition <- data.frame(class_id = seq_along(lower) - 1L, label = labels,
  lower_inclusive_minutes = lower,
  upper_exclusive_minutes = c(tail(lower, -1), Inf))
assign_duration_class <- function(minutes, cutoff_minutes = cutoff) {
  stopifnot(all(is.finite(minutes)), all(minutes >= 0))
  as.integer(pmin(floor(minutes / 10), cutoff_minutes / 10))
}
ids <- assign_duration_class(d)
counts <- definition
counts$training_count <- tabulate(ids + 1L, nbins = nrow(definition))
counts$training_pct <- 100 * counts$training_count / length(d)
stopifnot(sum(counts$training_count) == nrow(train),
 tail(counts$training_count, 1) == chosen$tail_count,
 identical(assign_duration_class(c(0, 9, 10, cutoff - 1, cutoff, 1440)),
           as.integer(c(0, 0, 1, cutoff / 10 - 1, cutoff / 10, cutoff / 10))))
dir.create(output, recursive = TRUE, showWarnings = FALSE)
write.csv(definition, file.path(output, "classes.csv"), row.names = FALSE)
write.csv(counts, file.path(output, "training_class_counts.csv"), row.names = FALSE)
write.csv(candidates, file.path(output, "cutoff_candidates.csv"), row.names = FALSE)
write.csv(chosen, file.path(output, "selected_cutoff.csv"), row.names = FALSE)
writeLines(c(
 "# Target definition: 10-minute duration classes", "",
 sprintf("Training: 2011–2023, %s records. Input MD5: %s.", nrow(train), tools::md5sum(input)),
 sprintf("Selected cutoff: %s minutes; %s classes, including the final >=cutoff class.", cutoff, nrow(definition)),
 sprintf("Tail: %s records. Other classes: mean %.2f, median %.1f, minimum %s.",
 chosen$tail_count, chosen$mean_regular_count, chosen$median_regular_count, chosen$min_regular_count),
 "", "Selection minimises the absolute count difference between the tail and the arithmetic mean of preceding classes.",
 "No validation or test durations were used to choose the cutoff. Freeze this definition before modelling.",
 "Intervals include the lower bound and exclude the upper bound. The final class has no upper bound.",
 "A smaller tail does not establish statistical insignificance or improved model performance.",
 "Fixed-width bins remain highly imbalanced. Do not oversample validation/test data or relabel rare classes per model.",
 "All models must output probabilities in classes.csv order. A class absent in a tuning-training fold needs an explicit shared policy.",
 "The original clean CSV is unchanged; the target is a modelling derivation."
), file.path(output, "README.md"))
print(chosen)
cat("Number of classes:", nrow(definition), "\n")
