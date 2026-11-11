# Regenerate publication-ready figures from saved summaries; no model fitting.
# Source from repository root. Display aggregation does not change model classes.
local({
  output <- "moddeling/04_logistic_regression/output"
  comparison <- read.csv(file.path(output,"validation_comparison.csv"))
  draw_loss <- function() {
    par(mar=c(5,12,3,1))
    labels<-c("Global baseline","Cause baseline (retrospective)","Multinomial: time only","Multinomial: archived context")
    heights<-rev(comparison$log_loss)
    locations<-barplot(heights,names.arg=rev(labels),horiz=TRUE,las=1,
      col=rev(c("#8C96A0","#D9A066","#2878A0","#B45124")),xlim=c(0,max(heights)*1.15),
      xlab="2024 validation multiclass log loss (lower is better)",
      main="Baseline and ridge multinomial comparison",cex.names=.85,border=NA)
    text(heights,locations,labels=sprintf(" %.4f",heights),pos=4,cex=.85)
  }
  draw_confusion <- function() {
    bin<-c(rep(1L,3),rep(2L,3),rep(3L,6),rep(4L,18),rep(5L,71),6L)
    bin_labels<-c("0 to <30","30 to <60","60 to <120","120 to <300","300 to <1010","1010+")
    par(mfrow=c(1,2),mar=c(7,7,4,2),oma=c(1,0,0,0))
    for(f in c("time_only","archived_context")) {
      cm<-as.matrix(read.csv(file.path(output,paste0(f,"_confusion_matrix.csv")),row.names=1,check.names=FALSE))
      agg<-matrix(0,6,6)
      for(i in 1:102)for(j in 1:102)agg[bin[i],bin[j]]<-agg[bin[i],bin[j]]+cm[i,j]
      normalised<-agg/pmax(rowSums(agg),1)
      image(1:6,1:6,t(normalised[6:1,,drop=FALSE]),col=hcl.colors(30,"Blues 3",rev=TRUE),
        zlim=c(0,1),axes=FALSE,xlab="",ylab="",main=if(f=="time_only")"Time-only ridge" else "Archived-context ridge (retrospective)")
      axis(1,at=1:6,labels=bin_labels,las=2,cex.axis=.7)
      axis(2,at=1:6,labels=rev(bin_labels),las=2,cex.axis=.7)
      mtext("Predicted interval (minutes)",1,line=5.5);mtext("True interval (minutes)",2,line=5.5)
      for(i in 1:6)for(j in 1:6)text(j,7-i,sprintf("%.0f%%",100*normalised[i,j]),cex=.8,
        col=if(normalised[i,j]>.6)"white" else "black")
    }
    mtext("Shares within each true interval; bins aggregated for display only",outer=TRUE,line=-.5,cex=.8)
  }
  for(name in c("validation_log_loss","logistic_confusion_matrices")) {
    width<-if(name=="validation_log_loss")9 else 12
    height<-if(name=="validation_log_loss")5 else 6
    draw<-if(name=="validation_log_loss")draw_loss else draw_confusion
    pdf(file.path(output,paste0(name,".pdf")),width=width,height=height)
    tryCatch(draw(),finally=dev.off())
  }
})
