# Synthetic evaluator tests only. Run from repository root.
source("moddeling/07_evaluatie/evaluate.R")
protected <- c("data/disruptions_2011_2025_clean.csv",
  list.files("moddeling/01_target", recursive = TRUE, full.names = TRUE),
  list.files("moddeling/02_voorbereiding", recursive = TRUE, full.names = TRUE))
before <- tools::md5sum(protected)
classes <- evaluation_classes("moddeling/01_target/output/classes.csv")
labels <- classes$label
checks <- character()
check <- function(x, name) {
  if (!isTRUE(x)) stop(name)
  checks <<- c(checks, name)
}
close <- function(x, y) isTRUE(all.equal(as.numeric(x), as.numeric(y), tolerance = 1e-12))
fixture <- function(truth, probabilities) {
  d <- data.frame(rdt_id = paste0("synthetic_", seq_along(truth)), split = "validation",
    model = "synthetic", feature_set = "time_only", true_class = labels[truth],
    predicted_class = labels[max.col(probabilities, ties.method = "first")])
  colnames(probabilities) <- paste0("p_", labels)
  cbind(d, as.data.frame(probabilities, check.names = FALSE))
}
prob <- matrix(0, 4, 102)
prob[1, c(1,2)] <- c(.8,.2)
prob[2, c(2,3)] <- c(.2,.8)
prob[3, c(3,1)] <- c(.1,.9)
prob[4, c(102,101)] <- c(.3,.7)
d <- fixture(c(1,2,3,102), prob)
original <- d
r <- evaluate_predictions(d, expected_ids = d$rdt_id, expected_true_class = d$true_class)
check(close(r$summary$log_loss, -mean(log(c(.8,.2,.1,.3)))), "Known natural-log multiclass loss")
check(close(r$summary$accuracy, .25), "Known accuracy")
check(close(r$summary$macro_f1, (2/3)/102), "Fixed-102 macro-F1 convention")
check(close(r$summary$within_one_class_pct, 75), "Known within-one-class percentage")
check(close(r$summary$underestimation_rate, .5) && close(r$summary$overestimation_rate,.25), "Known under/overestimation rates")
check(identical(r$per_observation$class_offset, c(0L,1L,-2L,-1L)), "Ordinal signed offsets preserve row order")
check(identical(dim(r$confusion_matrix), c(102L,102L)) &&
  identical(rownames(r$confusion_matrix), labels) && identical(colnames(r$confusion_matrix),labels), "Full confusion matrix in fixed true-row/predicted-column order")
check(r$confusion_matrix[1,1] == 1 && r$confusion_matrix[2,3] == 1 &&
  r$confusion_matrix[3,1] == 1 && r$confusion_matrix[102,101] == 1 && sum(r$confusion_matrix)==4, "Known confusion matrix cells and total")
check(all(r$per_class$support[c(1,2,3,102)]==1) && sum(r$per_class$support)==4 &&
  r$per_class$recall[1]==1 && all(r$per_class$recall[c(2,3,102)]==0), "Known class recall and support")
check(is.na(r$per_class$recall[4]) && r$per_class$f1[4]==0 && r$per_class$f1[101]==0, "Absent-class recall NA and F1 zero, including false-positive-only class")
check(r$ordinal_summary$n[r$ordinal_summary$subset=="true_open_ended"]==1 &&
  r$ordinal_summary$underestimation_rate[r$ordinal_summary$subset=="true_open_ended"]==1, "Open-ended class separately reported without minute errors")
check(identical(d,original), "Evaluator leaves input unchanged")
perfect <- evaluate_predictions(fixture(1:102,diag(102)))
check(perfect$summary$log_loss==0 && perfect$summary$accuracy==1 &&
  perfect$summary$macro_f1==1 && perfect$summary$within_one_class_pct==100, "Perfect predictions for all classes")
uniform <- evaluate_predictions(fixture(c(1,102),matrix(1/102,2,102)))
check(close(uniform$summary$log_loss,log(102)), "Uniform probabilities give log(102)")
check(all(uniform$per_observation$predicted_class==labels[1]), "First maximum tie rule")
zero <- evaluate_predictions(fixture(2,matrix(c(1,rep(0,101)),nrow=1)))
check(is.infinite(zero$summary$log_loss), "Zero true probability produces infinite loss without clipping")
check(all(is.na(zero$ordinal_summary$accuracy[zero$ordinal_summary$n==0])), "Empty ordinal subsets report NA rates")
check(evaluate_predictions(d[c(4,1,3,2),])$per_observation$rdt_id[1]==d$rdt_id[4], "Arbitrary input row order is preserved")
factor_input <- d
factor_input$true_class <- factor(d$true_class,levels=labels,ordered=TRUE)
factor_input$predicted_class <- factor(d$predicted_class,levels=labels,ordered=TRUE)
check(close(evaluate_predictions(factor_input)$summary$macro_f1,r$summary$macro_f1), "Step 02 ordered factors accepted")
# Same synthetic predictions are accepted independently of model algorithm.
for (model in c("baseline", "multinomial_logistic", "random_forest", "gradient_boosting")) {
  z <- d; z$model <- model
  check(close(evaluate_predictions(z)$summary$log_loss,r$summary$log_loss), paste("Algorithm-independent",model))
}
reject <- function(z, pattern, name, ...) {
  msg <- tryCatch({evaluate_predictions(z,...); NULL}, error=function(e) conditionMessage(e))
  check(!is.null(msg) && grepl(pattern,msg,fixed=TRUE),name)
}
z <- d; z$rdt_id[2] <- z$rdt_id[1]; reject(z,"Duplicate disruption IDs","Reject duplicate IDs")
z <- d; z$rdt_id[1] <- NA; reject(z,"Missing/blank","Reject missing ID")
z <- d; z$model[1] <- " "; reject(z,"Missing/blank","Reject blank metadata")
z <- d; z$true_class[1] <- "invalid"; reject(z,"exact classes.csv labels","Reject unknown truth class")
z <- d; z$predicted_class[1] <- "invalid"; reject(z,"exact classes.csv labels","Reject unknown predicted class")
z <- d; z$true_class[1] <- NA; reject(z,"Missing/blank","Reject missing truth")
z <- d; z$true_class <- factor(z$true_class,levels=rev(labels)); reject(z,"factor levels","Reject reversed factor class order")
z <- d; z[[7]][1] <- NA_real_; reject(z,"missing, NaN or infinite","Reject missing probability")
z <- d; z[[7]][1] <- Inf; reject(z,"missing, NaN or infinite","Reject infinite probability")
z <- d; z[[7]][1] <- NaN; reject(z,"missing, NaN or infinite","Reject NaN probability")
z <- d; z[[7]][1] <- -.1; reject(z,"[0,1]","Reject negative probability")
z <- d; z[[7]][1] <- 1.1; reject(z,"[0,1]","Reject probability above one")
z <- d; z[[7]][1] <- .7; reject(z,"row sums","Reject non-unit probability row sum")
z <- d; z[[7]] <- as.character(z[[7]]); reject(z,"must be numeric","Reject character probability")
z <- d[,c(1:6,8,7,9:108)]; reject(z,"Column names/order","Reject swapped probability columns")
reject(d[,-108],"Column names/order","Reject missing probability column")
z <- d; z$extra <- 1; reject(z,"Column names/order","Reject unexpected extra column")
z <- d; names(z)[8] <- names(z)[7]; reject(z,"Duplicate input column","Reject duplicate column names")
z <- d; z$predicted_class[1] <- labels[2]; reject(z,"first maximum","Reject inconsistent argmax prediction")
z <- fixture(1,matrix(1/102,1,102)); z$predicted_class <- labels[2]; reject(z,"first maximum","Reject inconsistent tied prediction")
z <- d; z$model[1] <- "another"; reject(z,"one model","Reject pooled models")
z <- d; z$split[1] <- "train"; reject(z,"one split","Reject pooled splits")
z <- d; z$feature_set[1] <- "archived_context"; reject(z,"one feature_set","Reject pooled feature sets")
z <- d; z$feature_set <- "unknown"; reject(z,"feature_set must","Reject unsupported feature set")
z <- d; z$split <- "2024"; reject(z,"split must","Reject unsupported split label")
z <- d; z$split <- "test"; reject(z,"Test evaluation is locked","Test split rejected by default; no test evaluation performed")
reject(d[0,],"nonempty","Reject empty predictions")
reject(d,"expected_ids exactly","Reject reordered cohort",expected_ids=rev(d$rdt_id))
reject(d[-1,],"expected_ids exactly","Reject incomplete cohort",expected_ids=d$rdt_id)
reject(d,"expected_true_class","Reject mismatched reference labels",expected_true_class=rev(d$true_class))
reject(d,"probability_tolerance","Reject invalid tolerance",probability_tolerance=NA_real_)
reject(d,"allow_test","Reject invalid test-unlock argument",allow_test=NA)
check(identical(before,tools::md5sum(protected)), "Clean dataset, Step 01 and Step 02 unchanged")
output <- "moddeling/07_evaluatie/output"
dir.create(output,recursive=TRUE,showWarnings=FALSE)
write.csv(data.frame(check=checks,result="PASS"),file.path(output,"synthetic_validation_checks.csv"),row.names=FALSE)
write.csv(r$summary,file.path(output,"synthetic_metrics.csv"),row.names=FALSE)
write.csv(r$per_class,file.path(output,"synthetic_per_class.csv"),row.names=FALSE,na="NA")
write.csv(as.data.frame.matrix(r$confusion_matrix),file.path(output,"synthetic_confusion_matrix.csv"),row.names=TRUE)
write.csv(r$ordinal_summary,file.path(output,"synthetic_ordinal_summary.csv"),row.names=FALSE,na="NA")
writeLines(c("# Synthetic evaluator verification", "",paste(length(checks),"checks passed."),
 "All metrics are from artificial predictions, not model results. No real outcomes were evaluated.",
 "2025 test evaluation was not run. Protected input hashes are unchanged.",
 paste("Class table MD5:",r$settings$classes_md5),"",capture.output(sessionInfo())),file.path(output,"verification_report.md"))
cat(length(checks),"synthetic checks passed.\n")
print(r$summary)
