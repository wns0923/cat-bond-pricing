# functions.R
library(tidyverse); library(evd)

simulate_years <- function(n_years, lambda, sigma, xi, u, cap, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  n_ev <- rpois(n_years, lambda)
  sev  <- pmin(rgpd(sum(n_ev), loc = u, scale = sigma, shape = xi), cap)
  yr   <- rep.int(seq_len(n_years), n_ev)
  max_loss <- numeric(n_years); agg_loss <- numeric(n_years)
  if (length(sev) > 0) {
    agg <- rowsum(sev, yr)
    agg_loss[as.integer(rownames(agg))] <- agg[, 1]
    mx <- tapply(sev, yr, max)
    max_loss[as.integer(names(mx))] <- as.numeric(mx)
  }
  tibble(sim_year = seq_len(n_years), n_events = n_ev, max_loss, agg_loss)
}

tranche_stats <- function(L, A, D) {
  ell <- pmin(1, pmax(0, (L - A) / (D - A)))
  tibble(EL = mean(ell), se_EL = sd(ell) / sqrt(length(L)),
         p_attach = mean(L > A), p_exhaust = mean(L >= D), sd_loss = sd(ell))
}

# spread (as a fraction) implied by the market line fitted on the benchmarks
predict_spread <- function(el, fit) {
  as.numeric(exp(predict(fit, newdata = data.frame(el_pct = el * 100))) / 100)
}