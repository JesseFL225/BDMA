# Validation selection and uncertainty

Development comparison only: 2024 has already informed earlier experiments; 2025 is untouched.
Primary selection: minimum log loss, separately for each feature set. RPS, exact accuracy and calibration are diagnostics.
Proposed time-only model: survival_recent_time
Proposed archived-context model: forest_context

## Full comparison

                     key      split                               model
          forest_context validation        random_forest_prior_smoothed
 survival_recent_context validation      discrete_time_hazard_since2017
        survival_context validation        discrete_time_hazard_xgboost
                   cause validation cause_group_shrinkage_retrospective
        logistic_context validation                   multinomial_ridge
        boosting_context validation                  xgboost_multiclass
    survival_recent_time validation      discrete_time_hazard_since2017
           survival_time validation        discrete_time_hazard_xgboost
             forest_time validation        random_forest_prior_smoothed
           logistic_time validation                   multinomial_ridge
           boosting_time validation                  xgboost_multiclass
                  global validation            global_frequency_laplace
      feature_set    n log_loss  accuracy    macro_f1 within_one_class_pct
 archived_context 5296 3.059072 0.1231118 0.006259617             26.56722
 archived_context 5296 3.062671 0.1185801 0.003241551             22.96073
 archived_context 5296 3.067781 0.1187689 0.003345296             22.97961
 archived_context 5296 3.071563 0.1178248 0.004701427             27.13369
 archived_context 5296 3.082036 0.1276435 0.009577578             27.96450
 archived_context 5296 3.084411 0.1163142 0.010395210             28.43656
        time_only 5296 3.190549 0.1193353 0.003939268             22.99849
        time_only 5296 3.193524 0.1193353 0.003939268             22.99849
        time_only 5296 3.213930 0.1174471 0.004159633             23.31949
        time_only 5296 3.217299 0.1178248 0.002700188             23.50831
        time_only 5296 3.219514 0.1185801 0.003628537             23.16843
        time_only 5296 3.230895 0.1172583 0.002057879             22.84743
 underestimation_rate overestimation_rate observed_classes macro_f1_classes
            0.8132553         0.063632931               97              102
            0.8538520         0.027567976               97              102
            0.8538520         0.027379154               97              102
            0.8243958         0.057779456               97              102
            0.7730363         0.099320242               97              102
            0.7539653         0.129720544               97              102
            0.8595166         0.021148036               97              102
            0.8595166         0.021148036               97              102
            0.8564955         0.026057402               97              102
            0.8772659         0.004909366               97              102
            0.8659366         0.015483384               97              102
            0.8827417         0.000000000               97              102
        rps central80_class_coverage mean_interval_class_count
 0.04991259                0.9084215                  24.60461
 0.05040183                0.9035121                  23.07723
 0.05052095                0.9072885                  23.60536
 0.05113968                0.8948263                  23.24887
 0.05118216                0.8959592                  23.78776
 0.05141848                0.9048338                  24.67315
 0.05565858                0.9135196                  25.44675
 0.05579619                0.9178625                  26.27002
 0.05600029                0.9199396                  26.27813
 0.05781783                0.9184290                  25.38539
 0.05716486                0.9186178                  25.88708
 0.05925542                0.9104985                  25.00000
 finite_interval_fraction mean_finite_interval_width_minutes
                0.9773414                           228.4467
                0.9775302                           213.7840
                0.9765861                           218.3546
                0.9831949                           219.3701
                0.9882931                           228.7944
                0.9765861                           228.4919
                0.9760196                           236.1559
                0.9760196                           244.5889
                0.9752644                           243.8529
                1.0000000                           253.8539
                0.9841390                           246.7632
                1.0000000                           250.0000

## Paired day bootstrap

                     key     comparator metric mean_difference      lower_95
           survival_time    forest_time   loss   -0.0204065147 -0.0299396637
           survival_time    forest_time    rps   -0.0002041014 -0.0003567450
        survival_context forest_context   loss    0.0087090966 -0.0007050548
        survival_context forest_context    rps    0.0006083643  0.0003100403
    survival_recent_time    forest_time   loss   -0.0233807218 -0.0331649693
    survival_recent_time    forest_time    rps   -0.0003417109 -0.0005184332
 survival_recent_context forest_context   loss    0.0035990369 -0.0058970103
 survival_recent_context forest_context    rps    0.0004892390  0.0001981230
      upper_95
 -1.098327e-02
 -6.123385e-05
  1.789483e-02
  9.473652e-04
 -1.410325e-02
 -1.791052e-04
  1.283922e-02
  8.402258e-04

Central 80% intervals include entire boundary bins, so discrete coverage can exceed 80% even for a calibrated model.
Finite widths exclude open-ended intervals; interpret alongside finite_interval_fraction. No midpoint for the final class.
These are model-based intervals, not calibrated/conformal guarantees. Calibration is assessed, not fitted on 2024.
Archived causes/locations may be revised. Outcome-selected <=24-hour archive limits generalization.
Survival formulation does not repair selection bias or reconstruct missing censored incidents.
Recent-period sensitivity uses fixed full-history settings and refitted preprocessing; it is not a fully retuned comparison.
All twelve prediction tables passed the unchanged evaluator with identical IDs, classes and labels.
