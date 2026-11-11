# Complete Step 04 run, from repository root. Test outcomes always locked.
source("moddeling/02_voorbereiding/prepare_data.R")
source("moddeling/07_evaluatie/evaluate.R")
source("moddeling/04_logistic_regression/logistic_regression.R")
source("moddeling/04_logistic_regression/validate_logistic_regression.R")
if(!requireNamespace("glmnet",quietly=TRUE))stop("Install glmnet first: install.packages('glmnet')")
set.seed(42)
started<-Sys.time()
protected<-c("data/disruptions_2011_2025_clean.csv",unlist(lapply(
 c("moddeling/01_target","moddeling/02_voorbereiding","moddeling/03_baselines","moddeling/07_evaluatie"),
 function(p)list.files(p,recursive=TRUE,full.names=TRUE)),use.names=FALSE))
before<-tools::md5sum(protected)
output<-"moddeling/04_logistic_regression/output"
dir.create(output,recursive=TRUE,showWarnings=FALSE)
lambdas<-c(.1,.01,.001)
features<-c("time_only","archived_context")
tuning<-data.frame()
for(year in c(2021L,2022L)) {
  fold<-prepare_data(train_years=2011:year,validation_years=year+1L,
    include_retrospective_cause=TRUE,include_test_outcomes=FALSE)
  for(f in features) {
    message("Tuning ",f,": train through ",year)
    model<-fit_multinomial(fold$train$X[[f]],fold$train$y,fold$class_levels,lambdas=lambdas)
    for(lambda in lambdas) {
      p<-predict_multinomial(model,fold$validation$X[[f]],lambda)
      table<-multinomial_prediction_table(fold,p,f)
      result<-evaluate_predictions(table,expected_ids=fold$validation$ids,expected_true_class=fold$validation$y)
      tuning<-rbind(tuning,data.frame(feature_set=f,alpha=0,lambda=lambda,
        train_through=year,validation_year=year+1L,train_n=length(fold$train$ids),
        validation_n=length(fold$validation$ids),feature_columns=ncol(fold$train$X[[f]]),
        minimum_training_class=min(model$training_counts),absent_classes=sum(model$training_counts==0),
        boundary_exclusions=sum(fold$exclusions$reason=="training_event_not_finished_before_validation"),
        preprocessing_training_only=identical(fold$preprocessing[[f]]$fit_ids,fold$train$ids),
        convergence_code=model$convergence_code,log_loss=result$summary$log_loss))
      message("  lambda=",lambda," fold log loss=",round(result$summary$log_loss,6))
    }
    rm(model,p,table,result);gc(FALSE)
  }
  rm(fold);gc(FALSE)
  write.csv(tuning,file.path(output,"tuning_fold_results.csv"),row.names=FALSE)
}
selection<-select_regularisation(tuning)
write.csv(selection$summary,file.path(output,"tuning_summary.csv"),row.names=FALSE)
write.csv(selection$selected,file.path(output,"selected_settings.csv"),row.names=FALSE)
# Settings frozen before preparing/scoring the final validation comparison.
prepared<-prepare_data(include_retrospective_cause=TRUE,include_test_outcomes=FALSE)
models<-predictions<-evaluations<-list()
for(f in features) {
  lambda<-selection$selected$lambda[selection$selected$feature_set==f]
  message("Final fit ",f,", selected lambda=",lambda)
  models[[f]]<-fit_multinomial(prepared$train$X[[f]],prepared$train$y,prepared$class_levels,lambdas=lambda)
  p<-predict_multinomial(models[[f]],prepared$validation$X[[f]],lambda)
  predictions[[f]]<-multinomial_prediction_table(prepared,p,f)
  evaluations[[f]]<-evaluate_predictions(predictions[[f]],expected_ids=prepared$validation$ids,
    expected_true_class=prepared$validation$y)
  con<-gzfile(file.path(output,paste0(f,"_validation_predictions.csv.gz")),"wt")
  tryCatch(write.csv(predictions[[f]],con,row.names=FALSE),finally=close(con))
  for(component in c("summary","per_class","ordinal_summary","per_observation")) {
    value<-evaluations[[f]][[component]]
    if(component=="per_observation") {
      con<-gzfile(file.path(output,paste0(f,"_",component,".csv.gz")),"wt")
      tryCatch(write.csv(value,con,row.names=FALSE),finally=close(con))
    } else write.csv(value,file.path(output,paste0(f,"_",component,".csv")),row.names=FALSE,na="NA")
  }
  write.csv(as.data.frame.matrix(evaluations[[f]]$confusion_matrix),
    file.path(output,paste0(f,"_confusion_matrix.csv")),row.names=TRUE)
}
baselines<-read.csv("moddeling/03_baselines/output/validation_comparison.csv")
baseline_checks<-vapply(c("global","cause"),function(name) {
  p<-read.csv(paste0("moddeling/03_baselines/output/",name,"_validation_predictions.csv.gz"),check.names=FALSE)
  e<-evaluate_predictions(p,expected_ids=prepared$validation$ids,expected_true_class=prepared$validation$y)
  expected<-baselines[baselines$model==e$summary$model,,drop=FALSE];rownames(expected)<-NULL
  isTRUE(all.equal(e$summary,expected,tolerance=1e-12))
},logical(1))
comparison<-rbind(baselines,do.call(rbind,lapply(evaluations,`[[`,"summary")))
rownames(comparison)<-NULL
write.csv(comparison,file.path(output,"validation_comparison.csv"),row.names=FALSE)
checks<-validate_logistic_regression(prepared,models,predictions,evaluations,tuning,selection$selected,baseline_checks)
for(f in features) {
  restored<-read.csv(file.path(output,paste0(f,"_validation_predictions.csv.gz")),check.names=FALSE)
  e<-evaluate_predictions(restored,expected_ids=prepared$validation$ids,expected_true_class=prepared$validation$y)
  if(!isTRUE(all.equal(e$summary,evaluations[[f]]$summary,tolerance=1e-12)))stop("Prediction round-trip changed scores.")
  checks<-rbind(checks,data.frame(check=paste(f,"saved prediction round-trip reproduces shared metrics"),result="PASS"))
}
if(!identical(before,tools::md5sum(protected)))stop("Protected files changed.")
checks<-rbind(checks,data.frame(check="Clean dataset and all files in Steps 01, 02, 03 and 07 unchanged",result="PASS"))
write.csv(checks,file.path(output,"validation_checks.csv"),row.names=FALSE)
source("moddeling/04_logistic_regression/plot_results.R")
source("moddeling/04_logistic_regression/write_report.R")
write.csv(data.frame(feature_set=features,n_train=vapply(models,`[[`,integer(1),"n_train"),
 convergence_code=vapply(models,`[[`,integer(1),"convergence_code"),
 passes=vapply(models,`[[`,integer(1),"passes")),file.path(output,"fit_diagnostics.csv"),row.names=FALSE)
writeLines(c("# Step 04 verification","",paste(nrow(checks),"checks passed."),
 paste("Runtime seconds:",round(as.numeric(difftime(Sys.time(),started,units="secs")),1)),
 paste("Dataset MD5:",prepared$audit$dataset_md5),paste("Classes MD5:",prepared$audit$classes_md5),
 "Seed 42. Ridge alpha=0; lambda grid 0.1, 0.01, 0.001.",
 "Pseudo-count 1 per class at training mean; numerical probability floor 1e-15.",
 "Archived context includes explicitly enabled retrospective cause information.",
 "No test outcomes imported, reconstructed or evaluated. Protected files unchanged.","",capture.output(sessionInfo())),
 file.path(output,"verification_report.md"))
print(selection$summary);print(selection$selected);print(comparison)
cat(nrow(checks),"checks passed.\n")
