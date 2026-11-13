# Final 2025 test — frozen-model results

Model choices and diagnostics were fixed before opening 2025 outcomes, following user authorization on 13 November 2026.
No model was refitted on 2024 or 2025. Existing fitted models and reconstructed training preprocessing were used.

| Model | Test n | Log loss | Exact accuracy | RPS |
|---|---:|---:|---:|---:|
| survival_recent_time | 5948 | 3.1620 | 10.93% | 0.05908 |
| survival_recent_time_baseline | 5948 | 3.2065 | 10.15% | 0.06422 |
| forest_context | 5948 | 3.0189 | 12.02% | 0.05048 |
| forest_context_baseline | 5948 | 3.0273 | 11.79% | 0.05178 |

## Paired comparison with matched baseline

                  key                    comparator mean_log_loss_difference
 survival_recent_time survival_recent_time_baseline             -0.044482111
       forest_context       forest_context_baseline             -0.008306917
    lower_95    upper_95 replicates days
 -0.06630526 -0.02464682        500  365
 -0.01508142 -0.00118420        500  365

## Validation versus test

                  key log_loss_2024 accuracy_2024   rps_2024 log_loss_2025
       forest_context      3.059072     0.1231118 0.04991259      3.018948
 survival_recent_time      3.190549     0.1193353 0.05565858      3.162023
 accuracy_2025   rps_2025
     0.1202085 0.05048053
     0.1092804 0.05908213

## Interpretation and limits

Negative log-loss differences favour the selected model. Baselines use the matching training years and information set.
Time-only and archived-context results are separate experiments; context includes potentially revised causes/locations.
Lower test loss than validation does not establish drift improvement: annual populations differ.
An 80% central class interval includes entire edge bins; observed coverage need not equal 80%.
Width summaries exclude infinite upper bounds and must be read with finite_interval_fraction. No guaranteed coverage.
The data exclude durations over 24 hours and other outcome-selected records. Results apply to that selected population.
Do not tune or choose a replacement using these test results. Later development needs a new holdout for a fresh final test.

See test_thresholds.csv, test_calibration.csv and test_groups.csv for probability diagnostics and supported subgroup errors.
