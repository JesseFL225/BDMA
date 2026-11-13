source("moddeling/13_survival/survival.R")
r <- risk_rows(c(1L, 2L, 101L, 102L))
stopifnot(identical(as.integer(table(r$person)), c(1L, 2L, 101L, 101L)),
  identical(as.integer(tapply(r$event, r$person, sum)), c(1L, 1L, 1L, 0L)))
h <- rbind(c(.2, .5), c(0, 0), c(1, .8))
expected <- rbind(c(.2, .4, .4), c(0, 0, 1), c(1, 0, 0))
stopifnot(isTRUE(all.equal(hazard_to_probability(h), expected)))
# Product of person-period likelihood terms equals the observed class mass,
# including a terminal tail observation without an artificial ending event.
hh <- matrix(seq(.01, .3, length.out = 404), nrow = 4)
pp <- hazard_to_probability(hh)
rr <- risk_rows(c(1L, 2L, 101L, 102L))
lik <- hh[cbind(rr$person, rr$interval)]
lik <- ifelse(rr$event == 1, lik, 1 - lik)
stopifnot(max(abs(as.numeric(tapply(log(lik), rr$person, sum)) -
 log(pp[cbind(1:4, c(1, 2, 101, 102))]))) < 1e-10)
# Empirical offset alone reconstructs the smoothed training class distribution.
mass <- seq_len(102) + 1
offset_h <- head(mass / rev(cumsum(rev(mass))), -1)
stopifnot(max(abs(hazard_to_probability(matrix(offset_h, nrow = 1)) - mass / sum(mass))) < 1e-12)
# Small integration check: serialization, row order, chunk invariance and fixed
# columns are essential to prevent plausible but incorrectly aligned outputs.
set.seed(42)
x <- matrix(rnorm(240), ncol = 3, dimnames = list(NULL, c("a", "b", "c")))
levels <- sprintf("class_%03d", 1:102)
y <- levels[rep(c(1, 2, 10, 102), each = 20)]
m <- fit_survival(x, y, levels, data.frame(max_depth = 2L, eta = .05, nrounds = 3L))
p <- predict_survival(m, x[1:5, ], 2L)
stopifnot(max(abs(rowSums(p) - 1)) < 1e-12,
 max(abs(p[5:1, ] - predict_survival(m, x[5:1, ], 3L))) < 1e-12,
 inherits(try(predict_survival(m, x[, 3:1]), silent = TRUE), "try-error"))
rm(m, p, x, y)
message("Survival risk-set, tail, likelihood, offset and prediction checks passed.")
