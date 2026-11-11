# Regularised multinomial models. Shared preparation/evaluation remain external.
# glmnet accepts a class-count response matrix; one training-mean pseudo-row
# supplies one count per class without deleting singleton/absent-class records.
fit_multinomial <- function(x, y, class_levels, lambdas = c(.1,.01,.001), alpha = 0,
                            pseudo_count = 1, probability_floor = 1e-15) {
  if (!requireNamespace("glmnet",quietly=TRUE)) stop("Install glmnet before running Step 04.")
  if (!is.matrix(x) || !is.numeric(x) || any(!is.finite(x)) || nrow(x)!=length(y) ||
      is.null(colnames(x)) || anyDuplicated(colnames(x))) stop("Invalid training matrix/labels.")
  if (length(class_levels)!=102 || anyNA(y) || any(!as.character(y)%in%class_levels)) stop("Invalid fixed class contract.")
  if (any(!is.finite(lambdas)) || any(lambdas<=0) || anyDuplicated(lambdas) ||
      length(alpha)!=1 || !is.finite(alpha) || alpha<0 || alpha>1 ||
      length(pseudo_count)!=1 || !is.finite(pseudo_count) || pseudo_count<=0 ||
      length(probability_floor)!=1 || !is.finite(probability_floor) || probability_floor<=0 || probability_floor>=1/102)
    stop("Invalid regularisation or smoothing parameters.")
  labels <- match(as.character(y),class_levels)
  response <- matrix(0,nrow(x)+1L,length(class_levels),dimnames=list(NULL,class_levels))
  response[cbind(seq_len(nrow(x)),labels)] <- 1
  response[nrow(response),] <- pseudo_count
  mean_features <- colMeans(x)
  augmented <- rbind(x,mean_features)
  warnings <- character()
  set.seed(42)
  fit <- withCallingHandlers(glmnet::glmnet(augmented,response,family="multinomial",alpha=alpha,
    lambda=sort(lambdas,decreasing=TRUE),standardize=FALSE,intercept=TRUE,
    thresh=1e-7,maxit=100000,type.multinomial="ungrouped"),warning=function(w) {
      warnings <<- c(warnings,conditionMessage(w));invokeRestart("muffleWarning")
    })
  if (fit$jerr!=0 || length(fit$lambda)!=length(lambdas) ||
      !isTRUE(all.equal(as.numeric(fit$lambda),sort(lambdas,decreasing=TRUE))))
    stop("glmnet did not successfully converge for the complete requested lambda path.")
  if (length(warnings)) stop(paste("glmnet warning requires review:",paste(warnings,collapse="; ")))
  list(fit=fit,class_levels=class_levels,feature_columns=colnames(x),alpha=alpha,
    lambdas=fit$lambda,n_train=nrow(x),training_counts=tabulate(labels,nbins=102),
    pseudo_count=pseudo_count,mean_features=mean_features,probability_floor=probability_floor,
    convergence_code=fit$jerr,passes=fit$npasses)
}

predict_multinomial <- function(model,x,lambda) {
  if (!is.matrix(x) || !identical(colnames(x),model$feature_columns) || any(!is.finite(x)))
    stop("Prediction features must be finite and match training columns exactly.")
  if (length(lambda)!=1 || !lambda%in%model$lambdas) stop("Use a fitted lambda, without interpolation.")
  a <- predict(model$fit,newx=x,s=lambda,type="response")
  if (!identical(dimnames(a)[[2]],model$class_levels)) stop("glmnet class order differs from the frozen contract.")
  p <- matrix(a[,,1],nrow=nrow(x),ncol=102,dimnames=list(NULL,model$class_levels))
  if (any(!is.finite(p)) || any(p<0) || any(rowSums(p)<=0)) stop("Invalid glmnet probability output.")
  # Fixed numerical safeguard only; never estimated from held-out labels.
  p <- pmax(p,model$probability_floor)
  p / rowSums(p)
}

multinomial_prediction_table <- function(prepared,p,feature_set,model="multinomial_ridge",split="validation") {
  if (split!="validation") stop("Step 04 generates validation/fold predictions only.")
  part <- prepared[[split]]
  if (nrow(p)!=length(part$ids) || !identical(colnames(p),prepared$class_levels)) stop("Prediction alignment mismatch.")
  result <- data.frame(rdt_id=part$ids,split=split,model=model,feature_set=feature_set,
    true_class=as.character(part$y),predicted_class=prepared$class_levels[max.col(p,ties.method="first")])
  p <- as.data.frame(p);names(p)<-prepared$probability_columns
  cbind(result,p)
}

# Equal weight per chronological validation YEAR; ties favour stronger ridge.
select_regularisation <- function(tuning) {
  if (any(!is.finite(tuning$log_loss)) || any(tuning$validation_year>=2024)) stop("Invalid training-only tuning scores.")
  keys <- unique(tuning[c("feature_set","alpha","lambda")])
  result <- lapply(seq_len(nrow(keys)),function(i) {
    k<-keys[i,];z<-tuning[tuning$feature_set==k$feature_set & tuning$alpha==k$alpha & tuning$lambda==k$lambda,]
    if (!identical(sort(z$validation_year),c(2022L,2023L))) stop("Every candidate requires both chronological folds.")
    data.frame(k,mean_log_loss=mean(z$log_loss),sd_log_loss=sd(z$log_loss))
  })
  summary<-do.call(rbind,result)
  chosen<-do.call(rbind,lapply(split(summary,summary$feature_set),function(z)
    z[order(z$mean_log_loss,-z$lambda,z$alpha),][1,]))
  rownames(chosen)<-NULL
  list(summary=summary,selected=chosen)
}
