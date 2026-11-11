# Called by the runner; no modification of shared verification reports.
validate_logistic_regression <- function(prepared,models,predictions,evaluations,tuning,selection,baseline_checks) {
  checks<-character()
  check<-function(x,s){if(!isTRUE(x))stop(s);checks<<-c(checks,s)}
  levels<-prepared$class_levels
  check(identical(prepared$classes,read.csv("moddeling/01_target/output/classes.csv")),"Exact reuse of frozen Step 01 definitions")
  check(identical(c(length(prepared$train$ids),length(prepared$validation$ids),length(prepared$test$ids)),c(33004L,5296L,5948L)),"Established actual split counts")
  check(!anyDuplicated(c(prepared$train$ids,prepared$validation$ids,prepared$test$ids)),"No duplicate/overlapping IDs")
  check(all(is.na(prepared$test$y))&&all(is.na(prepared$test$duration_minutes))&&!prepared$audit$test_outcomes_unlocked,"Test outcomes locked")
  check(identical(sort(unique(tuning$validation_year)),c(2022L,2023L)) &&
    all(tuning$train_through==tuning$validation_year-1L),"Only prescribed chronological forward folds used")
  check(nrow(tuning)==12L && all(tuning$preprocessing_training_only) && all(tuning$convergence_code==0),"All twelve feature/lambda/fold candidates converge with fold-training preprocessing")
  check(identical(selection,select_regularisation(tuning)$selected),"Selected settings derived exclusively from training-period scores")
  altered<-tuning;altered$validation_year[1]<-2024L
  rejected<-tryCatch({select_regularisation(altered);FALSE},error=function(e)TRUE)
  check(rejected,"Tuner rejects scores from 2024 or later")
  for(f in names(models)) {
    model<-models[[f]];p<-predictions[[f]]
    check(model$n_train==33004L && identical(model$training_counts,prepared$audit$training_class_counts),paste(f,"all real training observations retained"))
    check(identical(model$mean_features,colMeans(prepared$train$X[[f]])),paste(f,"pseudo-row derived only from training features"))
    check(!any(grepl("rdt_id|duration|end_time|statistical|difference|calculated|long_disruption",model$feature_columns)),paste(f,"no forbidden predictors"))
    check(identical(names(p),c("rdt_id","split","model","feature_set","true_class","predicted_class",prepared$probability_columns)),paste(f,"exact evaluator column contract"))
    probs<-as.matrix(p[prepared$probability_columns])
    check(identical(dim(probs),c(5296L,102L))&&all(is.finite(probs))&&all(probs>0 & probs<=1)&&all(abs(rowSums(probs)-1)<1e-12),paste(f,"finite positive normalised 102-class output"))
    check(identical(p$predicted_class,levels[max.col(probs,ties.method="first")] ),paste(f,"fixed first-maximum class rule"))
    check(identical(p$rdt_id,prepared$validation$ids)&&identical(p$true_class,as.character(prepared$validation$y))&&
      evaluations[[f]]$settings$cohort_verified&&evaluations[[f]]$settings$truth_verified,paste(f,"shared evaluator verifies exact ID/label alignment"))
  }
  check(all(baseline_checks),"Both saved baseline tables reproduce their saved scores on identical validation IDs")
  set.seed(42)
  x<-matrix(rnorm(120),40,3,dimnames=list(NULL,c("a","b","c")))
  y<-levels[c(rep(1,30),rep(2,9),3)] # one singleton and 99 absent classes
  fit<-fit_multinomial(x,y,levels,lambdas=c(.1,.01))
  p<-predict_multinomial(fit,x,.1)
  check(sum(fit$training_counts==0)==99 && sum(fit$training_counts==1)==1 &&
    ncol(p)==102 && all(p>0) && all(abs(rowSums(p)-1)<1e-12),"Synthetic singleton/absent classes fitted without discarding observations")
  check(identical(colnames(p),levels),"Synthetic absent classes preserve exact output order")
  repeat_fit<-fit_multinomial(x,y,levels,lambdas=c(.1,.01))
  check(identical(p,predict_multinomial(repeat_fit,x,.1)),"Seed-42 refit reproducibility on synthetic data")
  rejected<-tryCatch({predict_multinomial(fit,x[,3:1],.1);FALSE},error=function(e)TRUE)
  check(rejected,"Misordered prediction columns rejected")
  changed<-prepared
  changed$validation$y[]<-levels[1]
  check(identical(changed$train,prepared$train)&&identical(changed$preprocessing,prepared$preprocessing),"Held-out label changes leave all model-fitting inputs unchanged")
  data.frame(check=checks,result="PASS")
}
