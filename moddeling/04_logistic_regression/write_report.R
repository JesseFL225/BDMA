# Export a report-ready paragraph from actual saved comparison results.
local({
 output<-"moddeling/04_logistic_regression/output"
 m<-read.csv(file.path(output,"validation_comparison.csv"))
 paragraph<-sprintf(paste0(
 "Regularised multinomial logistic regression predicted 102 fixed duration classes using 33,004 training events from 2011-2023. ",
 "Training-only chronological validation on 2022 and 2023 selected ridge alpha=0 and lambda=0.001 for both feature sets. ",
 "On the common 2024 validation cohort (n=5,296), time-only regression achieved log loss %.4f and accuracy %.2f%%, versus %.4f and %.2f%% for the global baseline. ",
 "Archived-context regression achieved log loss %.4f, accuracy %.2f%% and macro-F1 %.4f; its log loss was slightly worse than the cause-group baseline (%.4f), despite higher accuracy. ",
 "Thus, the time-only model provided a small probability-quality improvement, whereas the archived-context model did not improve on its relevant baseline under the primary metric. ",
 "Rare-class stabilisation added one pseudo-count per class at the training-feature mean. Archived information may have been revised after onset, so retrospective results do not establish real-time deployability. The 2025 outcomes remained unexamined."),
 m$log_loss[3],100*m$accuracy[3],m$log_loss[1],100*m$accuracy[1],m$log_loss[4],100*m$accuracy[4],m$macro_f1[4],m$log_loss[2])
 writeLines(c("# Suggested Section 5 paragraph","",paragraph),file.path(output,"report_section_5.md"))
})
