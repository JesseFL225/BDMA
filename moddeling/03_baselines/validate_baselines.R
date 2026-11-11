# Tests invoked by run_baselines.R; no independent evaluator or real test access.
validate_baselines <- function(prepared, global_fit, cause_fit, predictions, evaluations) {
  checks <- character()
  check <- function(x, description) {
    if (!isTRUE(x)) stop(description)
    checks <<- c(checks, description)
  }
  near <- function(x, y) isTRUE(all.equal(unname(x), unname(y), check.attributes = FALSE, tolerance = 1e-12))
  levels <- prepared$class_levels
  # Tiny hand-counted training sample; 100 classes are deliberately absent.
  y <- levels[c(1,1,2)]
  g <- fit_global_baseline(y, levels, alpha = 1)
  check(near(g$probabilities[c(1,2,3)], c(3,2,1)/105), "Hand-calculated Laplace probabilities, including absent class")
  check(all(g$probabilities > 0) && abs(sum(g$probabilities)-1)<1e-12, "Absent classes receive positive normalised global probabilities")
  cfit <- fit_cause_baseline(y, c("A","A","__MISSING__"), levels, lambda = 102)
  expected <- (c(2,rep(0,101)) + 102*g$probabilities)/104
  check(near(cfit$probabilities["A",],expected), "Hand-calculated cause shrinkage")
  check(near(predict_cause_baseline(cfit,c("new","__UNSEEN__")), predict_global_baseline(g,2)), "Unseen cause groups fall back exactly to global prior")
  check(near(predict_cause_baseline(cfit,"__MISSING__"), cfit$probabilities["__MISSING__",,drop=FALSE]), "Observed missing cause has explicit learned group")
  check(near(predict_cause_baseline(cfit,"A") + 0, cfit$probabilities["A",,drop=FALSE]) &&
    all(cfit$probabilities>0) && all(abs(rowSums(cfit$probabilities)-1)<1e-12), "Rare cause/class distributions remain positive and normalised")
  absent_missing <- fit_cause_baseline(y, rep("A",3), levels)
  check(near(predict_cause_baseline(absent_missing,"__MISSING__"),predict_global_baseline(g,1)), "Unobserved missing-cause group uses global fallback")
  synthetic <- prepared
  synthetic$audit$retrospective_cause <- TRUE
  synthetic$preprocessing$archived_context$categorical_levels$cause_group <- c("A","__MISSING__","__UNSEEN__")
  block <- diag(3)
  colnames(block) <- paste("cause_group", make.names(c("A","__MISSING__","__UNSEEN__"),unique=TRUE),sep="_")
  synthetic$validation$X$archived_context <- block
  check(identical(prepared_cause_groups(synthetic,"validation"),c("A","__MISSING__","__UNSEEN__")), "Cause adapter preserves Step 02 missing and unseen categories")
  train_groups <- prepared_cause_groups(prepared,"train")
  check(sum(global_fit$counts)==length(prepared$train$ids) &&
    identical(global_fit$counts, tabulate(prepared$train$class_id+1L,nbins=102)), "Global counts match retained training labels only")
  check(sum(cause_fit$counts)==length(prepared$train$ids) &&
    near(colSums(cause_fit$counts),global_fit$counts), "Conditional counts aggregate exactly to training counts")
  check(identical(cause_fit$global, global_fit), "Both baselines share exactly the same global training prior")
  for (group in cause_fit$groups) {
    check(identical(as.integer(cause_fit$counts[group,]),tabulate(
      prepared$train$class_id[train_groups==group]+1L,nbins=102)), paste("Training-only counts for cause",group))
  }
  changed <- prepared
  changed$validation$y <- factor(rep(levels[102],length(changed$validation$ids)),levels=levels,ordered=TRUE)
  changed$validation$X$archived_context[,] <- 0
  changed$test$X$archived_context[,] <- 0
  check(identical(fit_global_baseline(changed$train$y,levels), global_fit) &&
    identical(fit_cause_baseline(changed$train$y,prepared_cause_groups(changed,"train"),levels),cause_fit),
    "Changing held-out labels/features cannot affect fitted baseline probabilities")
  check(all(is.na(prepared$test$y)) && all(is.na(prepared$test$duration_minutes)) &&
    !prepared$audit$test_outcomes_unlocked, "2025 outcomes remain locked")
  check(identical(predictions$global$rdt_id,predictions$cause$rdt_id) &&
    identical(predictions$global$true_class,predictions$cause$true_class) &&
    nrow(predictions$global)==5296, "Both models use identical 5296 validation IDs and labels")
  for (name in names(predictions)) {
    table <- predictions[[name]]
    probs <- as.matrix(table[prepared$probability_columns])
    check(ncol(probs)==102 && all(is.finite(probs)) && all(probs>0 & probs<=1) &&
      all(abs(rowSums(probs)-1)<1e-12), paste(name,"valid positive 102-column probabilities"))
    check(identical(table$predicted_class,levels[max.col(probs,ties.method="first")]),paste(name,"predicted class agrees with fixed-order argmax"))
    check(isTRUE(evaluations[[name]]$settings$cohort_verified) &&
      isTRUE(evaluations[[name]]$settings$truth_verified),paste(name,"shared evaluator verified ID and truth alignment"))
  }
  check(all(apply(as.matrix(predictions$global[prepared$probability_columns]),2,function(x) length(unique(x))==1)), "Global predictions constant across validation observations")
  # Refit actual chronological folds, reusing Step 02 and no test labels.
  for (year in c(2021L,2022L)) {
    fold <- prepare_data(train_years=2011:year,validation_years=year+1L,include_retrospective_cause=TRUE)
    fg <- fit_global_baseline(fold$train$y,fold$class_levels)
    fc <- fit_cause_baseline(fold$train$y,prepared_cause_groups(fold,"train"),fold$class_levels)
    fp <- predict_cause_baseline(fc,prepared_cause_groups(fold,"validation"))
    check(fg$n_train==length(fold$train$ids) && all(fp>0) &&
      all(abs(rowSums(fp)-1)<1e-12) && identical(colnames(fp),levels) && all(is.na(fold$test$y)),
      paste("Chronological fold through",year,"refits compatible positive baseline probabilities"))
  }
  data.frame(check=checks,result="PASS")
}
