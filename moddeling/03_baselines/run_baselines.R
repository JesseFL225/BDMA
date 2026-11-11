# Run from repository root: Rscript moddeling/03_baselines/run_baselines.R
# Estimates only baseline frequencies; no logistic/forest/boosting training.
source("moddeling/02_voorbereiding/prepare_data.R")
source("moddeling/07_evaluatie/evaluate.R")
source("moddeling/03_baselines/baselines.R")
source("moddeling/03_baselines/validate_baselines.R")
set.seed(42) # Baselines are deterministic; recorded for the shared project contract.
protected <- c("data/disruptions_2011_2025_clean.csv", unlist(lapply(
 c("moddeling/01_target","moddeling/02_voorbereiding","moddeling/07_evaluatie"),
 function(p) list.files(p,recursive=TRUE,full.names=TRUE)),use.names=FALSE))
before <- tools::md5sum(protected)
# Explicit retrospective opt-in. No independent reading/encoding of causes.
prepared <- prepare_data(include_retrospective_cause=TRUE,include_test_outcomes=FALSE)
# Choices are fixed a priori, not tuned against 2024 or 2025 outcomes.
alpha <- 1
lambda <- 102
global_fit <- fit_global_baseline(prepared$train$y,prepared$class_levels,alpha)
cause_fit <- fit_cause_baseline(prepared$train$y,prepared_cause_groups(prepared,"train"),
 prepared$class_levels,alpha,lambda)
probabilities <- list(
 global=predict_global_baseline(global_fit,length(prepared$validation$ids)),
 cause=predict_cause_baseline(cause_fit,prepared_cause_groups(prepared,"validation")))
predictions <- list(
 global=baseline_prediction_table(prepared,probabilities$global,"global_frequency_laplace","time_only"),
 cause=baseline_prediction_table(prepared,probabilities$cause,"cause_group_shrinkage_retrospective","archived_context"))
evaluations <- lapply(predictions,function(p) evaluate_predictions(p,
 expected_ids=prepared$validation$ids,expected_true_class=prepared$validation$y))
checks <- validate_baselines(prepared,global_fit,cause_fit,predictions,evaluations)
if (!identical(before,tools::md5sum(protected))) stop("Protected files changed.")
checks <- rbind(checks,data.frame(check="Clean data and all Steps 01, 02 and 07 files unchanged",result="PASS"))
output <- "moddeling/03_baselines/output"
dir.create(output,recursive=TRUE,showWarnings=FALSE)
comparison <- do.call(rbind,lapply(evaluations,`[[`,"summary"))
rownames(comparison) <- NULL
write.csv(comparison,file.path(output,"validation_comparison.csv"),row.names=FALSE)
write.csv(checks,file.path(output,"validation_checks.csv"),row.names=FALSE)
write.csv(data.frame(prepared$classes,training_count=global_fit$counts,
 empirical_frequency=global_fit$counts/global_fit$n_train,
 smoothed_probability=as.numeric(global_fit$probabilities)),file.path(output,"global_training_distribution.csv"),row.names=FALSE)
conditional <- do.call(rbind,lapply(cause_fit$groups,function(group) data.frame(
 cause_group=group,training_group_n=unname(cause_fit$group_n[group]),
 class_label=prepared$class_levels,training_class_count=as.numeric(cause_fit$counts[group,]),
 smoothed_probability=as.numeric(cause_fit$probabilities[group,]))))
write.csv(conditional,file.path(output,"cause_training_distributions.csv"),row.names=FALSE)
validation_groups <- prepared_cause_groups(prepared,"validation")
write.csv(data.frame(cause_group=names(table(validation_groups)),records=as.integer(table(validation_groups)),
 uses_global_fallback=!names(table(validation_groups)) %in% cause_fit$groups),
 file.path(output,"validation_cause_coverage.csv"),row.names=FALSE)
for(name in names(predictions)) {
 # Lossless compressed CSV keeps the full 5296 x 108 prediction contract small.
 con <- gzfile(file.path(output,paste0(name,"_validation_predictions.csv.gz")),"wt")
 tryCatch(write.csv(predictions[[name]],con,row.names=FALSE),finally=close(con))
 restored <- read.csv(file.path(output,paste0(name,"_validation_predictions.csv.gz")),check.names=FALSE)
 restored_evaluation <- evaluate_predictions(restored,expected_ids=prepared$validation$ids,
   expected_true_class=prepared$validation$y)
 if (!isTRUE(all.equal(restored_evaluation$summary,evaluations[[name]]$summary,tolerance=1e-12)))
   stop("Saved prediction CSV did not reproduce evaluation.")
 checks <- rbind(checks,data.frame(check=paste(name,"compressed prediction round-trip preserves contract and metrics"),result="PASS"))
 for(component in c("per_class","ordinal_summary")) write.csv(evaluations[[name]][[component]],
   file.path(output,paste0(name,"_",component,".csv")),row.names=FALSE,na="NA")
 write.csv(as.data.frame.matrix(evaluations[[name]]$confusion_matrix),
   file.path(output,paste0(name,"_confusion_matrix.csv")),row.names=TRUE)
}
write.csv(checks,file.path(output,"validation_checks.csv"),row.names=FALSE)
writeLines(c("# Baseline run verification", "",
 paste(nrow(checks),"checks passed. All performance results are 2024 validation only."),
 paste("Training rows:",length(prepared$train$ids)),paste("Validation rows:",length(prepared$validation$ids)),
 paste("Preparation exclusions:",nrow(prepared$exclusions)),
 "Test outcomes: locked; no test predictions or evaluation generated.",
 paste("Global alpha:",alpha),paste("Cause prior mass lambda:",lambda),"Seed: 42 (deterministic algorithms).",
 paste("Dataset MD5:",prepared$audit$dataset_md5),paste("Classes MD5:",prepared$audit$classes_md5),
 paste("Unseen/missing cause validation rows using fallback:",sum(!validation_groups %in% cause_fit$groups)),
 "Protected input hashes verified unchanged.","",capture.output(sessionInfo())),file.path(output,"verification_report.md"))
cat(nrow(checks),"checks passed.\n")
print(comparison)
cat("Global modal class:",prepared$class_levels[which.max(global_fit$probabilities)],"\n")
cat("Results saved in",output,"\n")
