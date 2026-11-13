# Frozen fitted-model settings

## survival_recent_time
Training events: 31289
Feature columns: 45
List of 7
 $ settings:'data.frame':	1 obs. of  4 variables:
  ..$ candidate: chr "depth2_round250"
  ..$ max_depth: int 2
  ..$ eta      : num 0.05
  ..$ nrounds  : int 250
 $ params  :List of 11
  ..$ objective       : chr "binary:logistic"
  ..$ eval_metric     : chr "logloss"
  ..$ tree_method     : chr "hist"
  ..$ max_depth       : int 2
  ..$ eta             : num 0.05
  ..$ min_child_weight: num 20
  ..$ lambda          : num 10
  ..$ subsample       : num 1
  ..$ colsample_bytree: num 1
  ..$ nthread         : int 2
  ..$ seed            : int 42
 $ seed    : int 42
 $ NA      : NULL
 $ NA      : NULL
 $ NA      : NULL
 $ NA      : NULL

## forest_context
Training events: 33004
Feature columns: 86
List of 7
 $ settings    :'data.frame':	1 obs. of  3 variables:
  ..$ candidate    : chr "sqrt_leaf100"
  ..$ mtry_rule    : chr "sqrt"
  ..$ min_node_size: int 100
 $ NA          : NULL
 $ seed        : int 42
 $ num_trees   : int 200
 $ mtry        : num 9
 $ max_depth   : int 12
 $ prior_weight: num 0.01

R version 4.4.2 (2024-10-31)
Platform: aarch64-apple-darwin20
Running under: macOS 26.6.2

Matrix products: default
BLAS:   /Library/Frameworks/R.framework/Versions/4.4-arm64/Resources/lib/libRblas.0.dylib 
LAPACK: /Library/Frameworks/R.framework/Versions/4.4-arm64/Resources/lib/libRlapack.dylib;  LAPACK version 3.12.0

locale:
[1] C.UTF-8/C.UTF-8/C.UTF-8/C/C.UTF-8/C.UTF-8

time zone: Europe/Amsterdam
tzcode source: internal

attached base packages:
[1] stats     graphics  grDevices utils     datasets  methods   base     

loaded via a namespace (and not attached):
 [1] compiler_4.4.2    Matrix_1.7-1      tools_4.4.2       Rcpp_1.0.13      
 [5] xgboost_3.2.1.1   ranger_0.18.0     grid_4.4.2        data.table_1.16.0
 [9] jsonlite_1.8.8    lattice_0.22-6   
