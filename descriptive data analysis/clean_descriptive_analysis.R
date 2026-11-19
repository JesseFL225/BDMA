##### BDMA Group Project, Part B #####
##### Step 4: descriptive analysis of the clean disruption data #####
#
# Analyst: Max
#
# Run from the repository root (the folder that contains data/):
#   Rscript "descriptive data analysis/clean_descriptive_analysis.R"
# In RStudio: open Train-disruptions.Rproj and run this file from the top.
#
# Input:  data/disruptions_2011_2025_clean.csv
#         (built by "Data Cleaning/clean_disruptions.R"; one row = one disruption)
#         Data Cleaning/output/yearly_retention.csv
# Output: descriptive data analysis/clean_analysis_output/
#
# The script only reads the data. It never changes a file in data/.
# Only base R is used, so no packages have to be installed.


##### 1. Import and inspect the data #####

getwd()
list.files("data")

disruptions <- read.csv(
  "data/disruptions_2011_2025_clean.csv",
  na.strings = c("", "NA")
)

head(disruptions)
dim(disruptions)
names(disruptions)
str(disruptions)

# Count missing values in each column.
colSums(is.na(disruptions))

# The unit of observation is one disruption: every ID occurs once.
number_of_disruptions <- nrow(disruptions)
number_of_disruptions
sum(duplicated(disruptions$rdt_id))

# All tables and the figure are saved in this folder.
output_folder <- "descriptive data analysis/clean_analysis_output"
dir.create(output_folder, recursive = TRUE, showWarnings = FALSE)


##### 2. The target: how long does a disruption last? #####

duration <- disruptions$duration_minutes

## 2.1 Summary statistics

summary(duration)
sd(duration)
quantile(duration, probs = c(0.05, 0.25, 0.50, 0.75, 0.95, 0.99))

# The mean is about twice the median: the distribution is right-skewed.
round(mean(duration) / median(duration), digits = 2)

## 2.2 Share of disruptions that last longer than a number of minutes

# A function avoids repeating the same calculation (result in percent).
share_longer_than <- function(minutes, limit) {
  share <- mean(minutes > limit) * 100
  return(share)
}

round(share_longer_than(duration, limit = 30), digits = 1)
round(share_longer_than(duration, limit = 60), digits = 1)
round(share_longer_than(duration, limit = 120), digits = 1)
round(share_longer_than(duration, limit = 300), digits = 1)

# The long disruptions: how long do they last once they pass one hour?
long_disruptions <- subset(disruptions, duration_minutes > 60)
nrow(long_disruptions)
summary(long_disruptions$duration_minutes)

## 2.3 The 102 target classes of ten minutes

# Class 0 is [0, 10) minutes, class 1 is [10, 20), ..., class 100 is [1000, 1010)
# and class 101 is 1,010 minutes or more. %/% is integer division.
disruptions$duration_class <- duration %/% 10
disruptions$duration_class[disruptions$duration_class > 101] <- 101

# factor() with all 102 levels also counts classes that would be empty.
class_counts <- table(factor(disruptions$duration_class, levels = 0:101))
length(class_counts)
head(class_counts, n = 12)

# Share of the first classes and of the open final class, in percent.
round(head(class_counts, n = 6) / number_of_disruptions * 100, digits = 1)
round(class_counts["101"] / number_of_disruptions * 100, digits = 2)

# The largest class holds only a small part of the data, and many classes are rare.
round(max(class_counts) / number_of_disruptions * 100, digits = 1)
sum(class_counts < 50)

## 2.4 Outliers: the IQR rule (suited to skewed data)

first_quartile <- quantile(duration, probs = 0.25)
third_quartile <- quantile(duration, probs = 0.75)
interquartile_range <- third_quartile - first_quartile
upper_bound <- third_quartile + 1.5 * interquartile_range
upper_bound

sum(duration > upper_bound)
round(mean(duration > upper_bound) * 100, digits = 1)

# These "outliers" are real long disruptions, the ones a traveller cares about
# most. They are kept; removing them would remove part of what we predict.


##### 3. Duration by cause group #####

table(disruptions$cause_group)

# Share of disruptions longer than 60 minutes, used in aggregate() below.
share_over_60 <- function(minutes) {
  return(mean(minutes > 60) * 100)
}

count_by_cause <- aggregate(
  duration_minutes ~ cause_group,
  data = disruptions,
  FUN = length
)
first_quartile_by_cause <- aggregate(
  duration_minutes ~ cause_group,
  data = disruptions,
  FUN = quantile,
  probs = 0.25
)
median_by_cause <- aggregate(
  duration_minutes ~ cause_group,
  data = disruptions,
  FUN = median
)
third_quartile_by_cause <- aggregate(
  duration_minutes ~ cause_group,
  data = disruptions,
  FUN = quantile,
  probs = 0.75
)
share_over_60_by_cause <- aggregate(
  duration_minutes ~ cause_group,
  data = disruptions,
  FUN = share_over_60
)

# Check that the five tables list the cause groups in the same order.
all(count_by_cause$cause_group == first_quartile_by_cause$cause_group)
all(count_by_cause$cause_group == median_by_cause$cause_group)
all(count_by_cause$cause_group == third_quartile_by_cause$cause_group)
all(count_by_cause$cause_group == share_over_60_by_cause$cause_group)

duration_by_cause <- data.frame(
  cause_group = count_by_cause$cause_group,
  disruptions = count_by_cause$duration_minutes,
  share_of_disruptions_pct = round(
    count_by_cause$duration_minutes / number_of_disruptions * 100,
    digits = 1
  ),
  first_quartile_minutes = first_quartile_by_cause$duration_minutes,
  median_minutes = median_by_cause$duration_minutes,
  third_quartile_minutes = third_quartile_by_cause$duration_minutes,
  share_over_60_min_pct = round(share_over_60_by_cause$duration_minutes, digits = 1)
)

# Largest cause group first.
duration_by_cause <- duration_by_cause[
  order(duration_by_cause$disruptions, decreasing = TRUE),
]
duration_by_cause

# Check: the groups add up to all disruptions.
sum(duration_by_cause$disruptions) == number_of_disruptions


##### 4. Duration by start time #####

# start_hour, start_weekday (1 = Monday) and start_month are local Dutch time.

## 4.1 Hour of the day

count_by_hour <- aggregate(
  duration_minutes ~ start_hour,
  data = disruptions,
  FUN = length
)
median_by_hour <- aggregate(
  duration_minutes ~ start_hour,
  data = disruptions,
  FUN = median
)
share_over_60_by_hour <- aggregate(
  duration_minutes ~ start_hour,
  data = disruptions,
  FUN = share_over_60
)
all(count_by_hour$start_hour == median_by_hour$start_hour)
all(count_by_hour$start_hour == share_over_60_by_hour$start_hour)

duration_by_hour <- data.frame(
  start_hour = count_by_hour$start_hour,
  disruptions = count_by_hour$duration_minutes,
  median_minutes = median_by_hour$duration_minutes,
  share_over_60_min_pct = round(share_over_60_by_hour$duration_minutes, digits = 1)
)
duration_by_hour

# Night starts (01:00 to 05:59) are rare but long.
night_disruptions <- subset(disruptions, start_hour >= 1 & start_hour <= 5)
day_disruptions <- subset(disruptions, start_hour == 0 | start_hour >= 6)
nrow(night_disruptions)
round(nrow(night_disruptions) / number_of_disruptions * 100, digits = 1)
round(share_over_60(night_disruptions$duration_minutes), digits = 1)
round(share_over_60(day_disruptions$duration_minutes), digits = 1)

# Which causes start at night? Mostly engineering work that runs over.
head(sort(table(night_disruptions$cause_en), decreasing = TRUE), n = 5)

# From 06:00 to 23:59 the share over 60 minutes stays in a narrow range.
daytime_hours <- subset(duration_by_hour, start_hour >= 6)
round(sum(daytime_hours$disruptions) / number_of_disruptions * 100, digits = 1)
range(daytime_hours$share_over_60_min_pct)

## 4.2 Weekday and month

share_over_60_by_weekday <- aggregate(
  duration_minutes ~ start_weekday,
  data = disruptions,
  FUN = share_over_60
)
share_over_60_by_weekday$duration_minutes <- round(
  share_over_60_by_weekday$duration_minutes,
  digits = 1
)
share_over_60_by_weekday
range(share_over_60_by_weekday$duration_minutes)

share_over_60_by_month <- aggregate(
  duration_minutes ~ start_month,
  data = disruptions,
  FUN = share_over_60
)
share_over_60_by_month$duration_minutes <- round(
  share_over_60_by_month$duration_minutes,
  digits = 1
)
share_over_60_by_month
range(share_over_60_by_month$duration_minutes)


##### 5. How much does each variable tell us about duration? #####

# A linear model of log(duration) on one variable at a time. R-squared is the
# share of the variation in log(duration) that the variable explains.
# This describes the data; it is not one of the predictive models of Step 5.
disruptions$log_duration <- log(disruptions$duration_minutes)

model_cause <- lm(log_duration ~ cause_group, data = disruptions)
model_hour <- lm(log_duration ~ factor(start_hour), data = disruptions)
model_weekday <- lm(log_duration ~ factor(start_weekday), data = disruptions)
model_month <- lm(log_duration ~ factor(start_month), data = disruptions)
model_time <- lm(
  log_duration ~ factor(start_hour) + factor(start_weekday) + factor(start_month),
  data = disruptions
)

variance_explained <- data.frame(
  variable = c("cause group", "start hour", "weekday", "month",
               "hour, weekday and month together"),
  r_squared_pct = round(
    c(summary(model_cause)$r.squared,
      summary(model_hour)$r.squared,
      summary(model_weekday)$r.squared,
      summary(model_month)$r.squared,
      summary(model_time)$r.squared) * 100,
    digits = 1
  )
)
variance_explained


##### 6. Differences between years and between the data splits #####

## 6.1 Per year

# Raw and clean rows per year, written by the cleaning script.
yearly_retention <- read.csv("Data Cleaning/output/yearly_retention.csv")
yearly_retention

# Helper columns: 1 if the cause group is rolling stock / unknown, else 0.
disruptions$rolling_stock <- 0
disruptions$rolling_stock[disruptions$cause_group == "rolling stock"] <- 1
disruptions$unknown_cause <- 0
disruptions$unknown_cause[disruptions$cause_group == "unknown"] <- 1

median_by_year <- aggregate(
  duration_minutes ~ start_year,
  data = disruptions,
  FUN = median
)
share_over_60_by_year <- aggregate(
  duration_minutes ~ start_year,
  data = disruptions,
  FUN = share_over_60
)
rolling_stock_by_year <- aggregate(
  rolling_stock ~ start_year,
  data = disruptions,
  FUN = mean
)
unknown_cause_by_year <- aggregate(
  unknown_cause ~ start_year,
  data = disruptions,
  FUN = mean
)
all(yearly_retention$year == median_by_year$start_year)
all(yearly_retention$year == share_over_60_by_year$start_year)
all(yearly_retention$year == rolling_stock_by_year$start_year)
all(yearly_retention$year == unknown_cause_by_year$start_year)

duration_by_year <- data.frame(
  year = yearly_retention$year,
  raw_records = yearly_retention$raw_rows,
  clean_disruptions = yearly_retention$clean_rows,
  kept_pct = round(yearly_retention$retained_pct, digits = 1),
  median_minutes = median_by_year$duration_minutes,
  share_over_60_min_pct = round(share_over_60_by_year$duration_minutes, digits = 1),
  rolling_stock_pct = round(rolling_stock_by_year$rolling_stock * 100, digits = 1),
  unknown_cause_pct = round(unknown_cause_by_year$unknown_cause * 100, digits = 1)
)
duration_by_year

# Check: the yearly counts add up to the clean data.
sum(duration_by_year$clean_disruptions) == number_of_disruptions

## 6.2 Before and after the 2017 registration change

early_years <- subset(duration_by_year, year <= 2016)
later_years <- subset(duration_by_year, year >= 2017)

sum(early_years$clean_disruptions)
kept_early_pct <- round(
  sum(early_years$clean_disruptions) / sum(early_years$raw_records) * 100,
  digits = 1
)
kept_later_pct <- round(
  sum(later_years$clean_disruptions) / sum(later_years$raw_records) * 100,
  digits = 1
)
kept_early_pct
kept_later_pct

early_disruptions <- subset(disruptions, start_year <= 2016)
later_disruptions <- subset(disruptions, start_year >= 2017)
median(early_disruptions$duration_minutes)
median(later_disruptions$duration_minutes)
round(share_over_60(early_disruptions$duration_minutes), digits = 1)
round(share_over_60(later_disruptions$duration_minutes), digits = 1)

## 6.3 Training, validation and test years (the split used in Step 5)

disruptions$data_split <- NA
disruptions$data_split[disruptions$start_year <= 2023] <- "training 2011-2023"
disruptions$data_split[disruptions$start_year == 2024] <- "validation 2024"
disruptions$data_split[disruptions$start_year == 2025] <- "test 2025"
disruptions$data_split <- factor(
  disruptions$data_split,
  levels = c("training 2011-2023", "validation 2024", "test 2025")
)
sum(is.na(disruptions$data_split))
table(disruptions$data_split)

aggregate(duration_minutes ~ data_split, data = disruptions, FUN = median)
aggregate(duration_minutes ~ data_split, data = disruptions, FUN = share_over_60)
unknown_by_split <- aggregate(unknown_cause ~ data_split, data = disruptions, FUN = mean)
unknown_by_split$unknown_cause <- round(unknown_by_split$unknown_cause * 100, digits = 1)
unknown_by_split


##### 7. Figure for the report #####

# Three panels next to each other: the target, the cause and the start hour.
# par(mfrow = c(1, 3)) places three plots in one row.

# Order the cause groups from the shortest to the longest median duration.
cause_order <- duration_by_cause$cause_group[order(duration_by_cause$median_minutes)]
disruptions$cause_group_ordered <- factor(disruptions$cause_group, levels = cause_order)
levels(disruptions$cause_group_ordered)

# Durations are skewed, so the box plot uses log10(duration). The axis labels
# are written back in minutes.
disruptions$log10_duration <- log10(disruptions$duration_minutes)
minute_ticks <- c(1, 10, 60, 600)

# Light bars mark the night hours, which hold few disruptions.
hour_colours <- rep("steelblue", times = 24)
hour_colours[duration_by_hour$start_hour >= 1 & duration_by_hour$start_hour <= 5] <- "lightblue"

# Numbers that are written inside the figure.
share_300_or_longer <- round(mean(duration >= 300) * 100, digits = 1)
share_over_60_all <- round(share_longer_than(duration, limit = 60), digits = 1)
share_night <- round(nrow(night_disruptions) / number_of_disruptions * 100, digits = 0)

png(
  file.path(output_folder, "figure_descriptive_analysis.png"),
  width = 2600,
  height = 1000,
  res = 400,
  pointsize = 11
)
par(mfrow = c(1, 3), mar = c(4, 4.4, 2.6, 0.6), las = 1, cex.main = 1)

# Panel A. Histogram: one bar is one ten-minute target class.
# right = FALSE makes the bars [0, 10), [10, 20), ... like the target classes.
hist(
  duration[duration < 300],
  breaks = seq(from = 0, to = 300, by = 10),
  right = FALSE,
  col = "steelblue",
  border = "white",
  xaxt = "n",
  main = "A. Duration per 10-minute class",
  xlab = "Duration (minutes)",
  ylab = ""
)
axis(side = 1, at = seq(from = 0, to = 300, by = 60))
title(ylab = "Number of disruptions", line = 3.3)
abline(v = median(duration), lty = 2)
text(
  x = median(duration) + 8, y = 5600, adj = 0,
  labels = paste("median", median(duration), "min")
)
text(
  x = 298, y = 3400, adj = 1,
  labels = paste0(format(share_300_or_longer, nsmall = 1), "% last 300 min\nor longer (not shown)")
)

# Panel B. Box plot: duration by cause group, shortest median at the bottom.
# The box is the middle half of the disruptions; the thick line is the median.
par(mar = c(4, 7.2, 2.6, 0.6))
boxplot(
  log10_duration ~ cause_group_ordered,
  data = disruptions,
  horizontal = TRUE,
  outline = FALSE,
  col = "lightblue",
  frame = FALSE,
  xaxt = "n",
  ylim = log10(c(1, 1500)),
  main = "B. Duration by cause group",
  xlab = "Duration (minutes, log scale)",
  ylab = ""
)
axis(side = 1, at = log10(minute_ticks), labels = minute_ticks)
abline(v = log10(60), lty = 2)

# Panel C. Bar chart: share of disruptions over 60 minutes by start hour.
# barplot() returns the position of every bar; these are used for the labels.
par(mar = c(4, 4.4, 2.6, 0.6))
bar_positions <- barplot(
  duration_by_hour$share_over_60_min_pct,
  col = hour_colours,
  border = "white",
  ylim = c(0, 100),
  main = "C. Over 60 min, by start hour",
  xlab = "Start hour",
  ylab = "Longer than 60 min (%)"
)
axis(
  side = 1,
  at = bar_positions[c(1, 7, 13, 19, 24)],
  labels = c("0", "6", "12", "18", "23"),
  tick = FALSE,
  line = -0.6
)
abline(h = share_over_60_all, lty = 2)
text(
  x = bar_positions[24], y = share_over_60_all + 6, adj = 1,
  labels = paste0("all hours: ", format(share_over_60_all, nsmall = 1), "%")
)
text(
  x = bar_positions[8], y = 74, adj = 0,
  labels = paste0("01-05h: only ", share_night, "% of\nall disruptions")
)

dev.off()


##### 8. Export the tables #####

# row.names = FALSE avoids an extra numbered column.
write.csv(
  duration_by_cause,
  file.path(output_folder, "duration_by_cause_group.csv"),
  row.names = FALSE
)
write.csv(
  duration_by_hour,
  file.path(output_folder, "duration_by_start_hour.csv"),
  row.names = FALSE
)
write.csv(
  duration_by_year,
  file.path(output_folder, "duration_by_year.csv"),
  row.names = FALSE
)
write.csv(
  variance_explained,
  file.path(output_folder, "variance_explained.csv"),
  row.names = FALSE
)

# The numbers that the report text quotes, in one table.
report_numbers <- data.frame(
  number = c(
    "Cleaned disruptions",
    "Median duration (minutes)",
    "Mean duration (minutes)",
    "Longer than 60 minutes (%)",
    "300 minutes or longer (%)",
    "Median duration of the disruptions longer than 60 minutes (minutes)",
    "Target classes",
    "Largest class: share of disruptions (%)",
    "Classes with fewer than 50 disruptions",
    "Start 06:00-23:59: share of disruptions (%)",
    "Start 06:00-23:59: lowest hourly share over 60 minutes (%)",
    "Start 06:00-23:59: highest hourly share over 60 minutes (%)",
    "Start 01:00-05:59: share of disruptions (%)",
    "Start 01:00-05:59: share over 60 minutes (%)",
    "2011-2016: share of raw records kept (%)",
    "2017-2025: share of raw records kept (%)",
    "Training years 2011-2023: unknown cause (%)",
    "Validation year 2024: unknown cause (%)",
    "Test year 2025: unknown cause (%)"
  ),
  value = c(
    number_of_disruptions,
    median(duration),
    round(mean(duration), digits = 0),
    share_over_60_all,
    share_300_or_longer,
    median(long_disruptions$duration_minutes),
    length(class_counts),
    round(max(class_counts) / number_of_disruptions * 100, digits = 1),
    sum(class_counts < 50),
    round(sum(daytime_hours$disruptions) / number_of_disruptions * 100, digits = 1),
    min(daytime_hours$share_over_60_min_pct),
    max(daytime_hours$share_over_60_min_pct),
    round(nrow(night_disruptions) / number_of_disruptions * 100, digits = 1),
    round(share_over_60(night_disruptions$duration_minutes), digits = 1),
    kept_early_pct,
    kept_later_pct,
    unknown_by_split$unknown_cause[1],
    unknown_by_split$unknown_cause[2],
    unknown_by_split$unknown_cause[3]
  )
)
report_numbers

write.csv(
  report_numbers,
  file.path(output_folder, "report_numbers.csv"),
  row.names = FALSE
)

list.files(output_folder)
