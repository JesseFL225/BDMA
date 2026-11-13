# Error-analysis verification

All eight prediction files passed the unchanged shared evaluator with identical validation IDs and labels.
2025 labels remain locked. No test model selection or test evaluation performed.
Metadata-only CSV import; source data and Mart-owned steps unchanged.
Subgroup route memberships overlap. Groups under 50 are flagged; no small-group ranking claims.
Paired bootstrap: 500 resamples of observed calendar days, descriptive validation intervals after selection.
Grouped permutation: fixed random 2000-row validation subset, three repeats; no causal interpretation.
Open-ended class is evaluated separately; class offsets are not minute errors.

Dataset MD5: 6f22afc6b05fe5e65ed8bd583bc5ba68
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
[1] compiler_4.4.2 Matrix_1.7-1   tools_4.4.2    Rcpp_1.0.13    ranger_0.18.0 
[6] grid_4.4.2     lattice_0.22-6
