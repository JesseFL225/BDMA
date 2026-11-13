# Synthetic checks for the point-in-time history features (Step 11): a feature
# for a disruption may only use disruptions that had already ENDED before it
# started. Uses a tiny hand-made fixture; no real data or test outcomes.
source("moddeling/11_historische_kenmerken/history_features.R")
fixture <- data.frame(rdt_id = as.character(1:5),
 start_time = c("2020-01-01T00:00:00Z", "2020-01-01T01:00:00Z", "2020-01-01T02:00:00Z", "2020-01-01T02:00:00Z", "2020-01-02T02:00:00Z"),
 end_time = c("2020-01-01T00:30:00Z", "2020-01-01T03:00:00Z", "2020-01-01T02:30:00Z", "2020-01-01T03:00:00Z", "2020-01-02T03:00:00Z"),
 duration_minutes = c(30, 120, 30, 60, 60), rdt_lines_id = c("1,2", "1", "1,2", "1,2", "2"), cause_group = "technical")
h <- make_history_features(fixture)
stopifnot(all(h$checks[-1]), h$values$hist_route_starts_7d[3] == 2,
 h$values$hist_route_starts_7d[4] == 2, # Equal starts excluded; shared routes not double-counted.
 h$values$hist_route_completed_90d[3] == 1,
 h$values$hist_route_median_90d[3] == 30, # Ongoing event's outcome is unavailable.
 h$values$hist_global_median_90d_missing[1] == 1,
 h$values$hist_network_starts_24h[5] == 2) # Inclusive lower window bound.
equal_end <- fixture
equal_end$end_time[1] <- "2020-01-01T02:00:00Z"
boundary <- make_history_features(equal_end)
stopifnot(boundary$values$hist_route_completed_90d[3] == 0)
prefix <- make_history_features(fixture[1:3, ])
stopifnot(identical(h$values[1:3, ], prefix$values))
changed <- fixture; changed$duration_minutes[2:5] <- c(900, 800, 700, 600)
again <- make_history_features(changed)
stopifnot(identical(h$values[1:2, ], again$values[1:2, ]),
 identical(h$values[3, ], again$values[3, ])) # Future/current/ongoing labels cannot alter these features.
order <- c(5, 3, 1, 4, 2)
shuffled <- make_history_features(fixture[order, ])
stopifnot(isTRUE(all.equal(h$values, shuffled$values[match(h$ids, shuffled$ids), ], check.attributes = FALSE)))
cat("History checks passed: chronology, concurrent starts, unfinished outcomes, multi-route deduplication, cold starts, future-outcome invariance and row-order invariance.\n")
