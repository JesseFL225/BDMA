# Stateless, point-in-time history from the frozen selected archive.
# Input must not include 2025 outcomes. No current/simultaneous/future event is used.
source("moddeling/02_voorbereiding/prepare_data.R")
strictly_before <- function(t, sorted) {
  p <- findInterval(t, sorted)
  while (p > 0L && sorted[p] >= t) p <- p - 1L
  p
}
make_history_features <- function(events) {
  required <- c("rdt_id", "start_time", "end_time", "duration_minutes", "rdt_lines_id", "cause_group")
  stopifnot(all(required %in% names(events)), !anyDuplicated(events$rdt_id))
  st <- as.numeric(parse_utc(events$start_time)); en <- as.numeric(parse_utc(events$end_time))
  duration <- as.numeric(events$duration_minutes)
  stopifnot(all(is.finite(st)), all(is.finite(en)), all(en > st), all(is.finite(duration)), all(duration > 0))
  routes <- list_tokens(events$rdt_lines_id)
  # Route/cause values are archived values: these remain retrospective features.
  route_map <- split(rep(seq_len(nrow(events)), lengths(routes)), unlist(routes))
  causes <- ifelse(is.na(events$cause_group), "__MISSING__", events$cause_group)
  cause_map <- split(seq_len(nrow(events)), causes)
  starts <- sort(st); ends_order <- order(en); ends <- en[ends_order]
  rows <- vector("list", nrow(events))
  audit <- vector("list", nrow(events))
  for (i in seq_len(nrow(events))) {
    now <- st[i]; day <- 86400
    past <- strictly_before(now, starts)
    global24 <- past - strictly_before(now - day, starts)
    global7 <- past - strictly_before(now - 7 * day, starts)
    end_hi <- strictly_before(now, ends); end_lo <- strictly_before(now - 90 * day, ends)
    completed <- if (end_hi > end_lo) ends_order[seq.int(end_lo + 1L, end_hi)] else integer()
    route_ids <- unique(unlist(route_map[routes[[i]]], use.names = FALSE))
    route_past <- route_ids[st[route_ids] < now]
    route_done <- route_past[en[route_past] < now & en[route_past] >= now - 90 * day]
    cause_ids <- cause_map[[causes[i]]]
    cause_done <- cause_ids[st[cause_ids] < now & en[cause_ids] < now & en[cause_ids] >= now - 90 * day]
    med <- function(ids) if (length(ids)) median(duration[ids]) else NA_real_
    rows[[i]] <- data.frame(hist_network_starts_24h = global24, hist_network_starts_7d = global7,
      hist_global_completed_90d = length(completed), hist_global_median_90d = med(completed),
      hist_route_starts_7d = sum(st[route_past] >= now - 7 * day),
      hist_route_starts_30d = sum(st[route_past] >= now - 30 * day),
      hist_route_completed_90d = length(route_done), hist_route_median_90d = med(route_done),
      hist_cause_completed_90d = length(cause_done), hist_cause_median_90d = med(cause_done))
    used <- unique(c(completed, route_done, cause_done))
    audit[[i]] <- data.frame(rdt_id = events$rdt_id[i],
      no_self_or_future_outcome = !i %in% used && all(en[used] < now) && all(st[used] < now),
      no_self_or_simultaneous_route_start = !i %in% route_past && all(st[route_past] < now))
  }
  values <- do.call(rbind, rows)
  for (name in grep("median", names(values), value = TRUE))
    values[[paste0(name, "_missing")]] <- as.integer(is.na(values[[name]]))
  list(ids = as.character(events$rdt_id), values = values, checks = do.call(rbind, audit))
}
read_development_history <- function(path = "data/disruptions_2011_2025_clean.csv") {
  header <- names(read.csv(path, nrows = 0))
  cc <- setNames(rep("NULL", length(header)), header)
  cc[c("rdt_id", "start_time", "rdt_lines_id", "cause_group")] <- "character"
  meta <- read.csv(path, colClasses = cc, na.strings = c("", "NA"))
  year <- as.integer(format(parse_utc(meta$start_time), "%Y", tz = "Europe/Amsterdam"))
  rows <- which(year <= 2024)
  # Same selective reader as Mart; outcome columns of 2025 are not imported.
  stopifnot(length(count.fields(path, sep = ",", quote = "\"", blank.lines.skip = FALSE)) == nrow(meta) + 1L)
  outcomes <- read_selected_outcomes(path, rows, header)
  events <- cbind(meta[rows, ], outcomes)
  stopifnot(all(year[rows] <= 2024))
  events
}
augment_history <- function(prepared, history, feature_set) {
  columns <- if (feature_set == "time_only") grep("^hist_network_|^hist_global_", names(history$values), value = TRUE) else names(history$values)
  train <- history$values[match(prepared$train$ids, history$ids), columns, drop = FALSE]
  validation <- history$values[match(prepared$validation$ids, history$ids), columns, drop = FALSE]
  stopifnot(!anyNA(match(prepared$train$ids, history$ids)), !anyNA(match(prepared$validation$ids, history$ids)))
  # Cold-start medians: training-fitted fallback; missingness remains explicit.
  medians <- vapply(train, function(v) if (all(is.na(v))) 0 else median(v, na.rm = TRUE), numeric(1))
  for (name in columns) {
    train[[name]][is.na(train[[name]])] <- medians[[name]]
    validation[[name]][is.na(validation[[name]])] <- medians[[name]]
  }
  x <- cbind(prepared$train$X[[feature_set]], as.matrix(train))
  v <- cbind(prepared$validation$X[[feature_set]], as.matrix(validation))
  stopifnot(all(is.finite(x)), all(is.finite(v)), identical(colnames(x), colnames(v)))
  list(train = x, validation = v, imputation = medians, columns = columns)
}
