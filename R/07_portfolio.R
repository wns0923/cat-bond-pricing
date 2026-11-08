# 07_portfolio.R
library(tidyverse); library(quadprog)
source('R/functions.R')
hurr     <- readRDS('data/clean/hurr.rds')
mk       <- readRDS('data/clean/mk.rds')
sim      <- readRDS('data/clean/sim.rds')
p        <- readRDS('data/clean/params.rds')
tranches <- readRDS('data/clean/tranches.rds')
fit_mkt  <- readRDS('data/clean/fit_mkt.rds')

rf <- mean(mk$tbill)     # sample-average T-bill, consistent with the historical returns

# 1. test the correlation claim with real history
hist_loss <- hurr |> filter(loss_bn > p$u) |> group_by(year) |>
  summarise(loss = sum(loss_bn)) |>
  right_join(tibble(year = 1980:2024), by = 'year') |>
  replace_na(list(loss = 0)) |> left_join(mk, by = 'year')

cor(hist_loss$loss, hist_loss$sp500,   method = 'spearman')
cor(hist_loss$loss, hist_loss$tbond10, method = 'spearman')
boot_cor <- function(v) replicate(5000, {
  i <- sample(nrow(hist_loss), replace = TRUE)
  cor(hist_loss$loss[i], hist_loss[[v]][i], method = 'spearman')
})
quantile(boot_cor('sp500'),   c(0.05, 0.95))   # an interval containing 0 is your evidence
quantile(boot_cor('tbond10'), c(0.05, 0.95))

# 2. joint returns: each simulated hurricane year paired with a random market year
set.seed(7)
idx  <- sample(nrow(mk), nrow(sim), replace = TRUE)
mezz <- tranches |> filter(name == 'Mezzanine')
ell  <- pmin(1, pmax(0, (sim$max_loss - mezz$attach_bn) / (mezz$exhaust_bn - mezz$attach_bn)))
s_m  <- predict_spread(mean(ell), fit_mkt)
rets <- cbind(stock = mk$sp500[idx], bond = mk$tbond10[idx], cat = rf + s_m - ell)
mu <- colMeans(rets); Sigma <- cov(rets)

# 3. efficient frontier
frontier <- function(mu, Sigma, rf, n_pts = 60) {
  n <- length(mu)
  targets <- seq(min(mu) + 1e-4, max(mu) - 1e-4, length.out = n_pts)
  Amat <- cbind(rep(1, n), mu, diag(n))
  map_dfr(targets, function(m) {
    sol <- solve.QP(2 * Sigma, rep(0, n), Amat, c(1, m, rep(0, n)), meq = 2)
    w <- sol$solution
    risk <- sqrt(sum(w * (Sigma %*% w)))
    tibble(ret = sum(w * mu), risk = risk,
           sharpe = (sum(w * mu) - rf) / risk,
           w = list(setNames(w, names(mu))))
  })
}
fr_with    <- frontier(mu, Sigma, rf)
fr_without <- frontier(mu[1:2], Sigma[1:2, 1:2], rf)
best_with    <- slice_max(fr_with, sharpe, n = 1)
best_without <- slice_max(fr_without, sharpe, n = 1)
c(without = best_without$sharpe, with = best_with$sharpe)
best_with$w[[1]]

# 4. tail risk
cvar <- function(r, a = 0.05) mean(r[r <= quantile(r, a)])
port_with    <- rets %*% best_with$w[[1]]
port_without <- rets[, 1:2] %*% best_without$w[[1]]
c(without = cvar(port_without), with = cvar(port_with))

bind_rows(fr_with |> mutate(portfolio = 'With cat bond'),
          fr_without |> mutate(portfolio = 'Without')) |>
  group_by(portfolio) |> filter(ret >= ret[which.min(risk)]) |> ungroup() |>
  ggplot(aes(risk, ret, color = portfolio)) + geom_line(linewidth = 1) +
  labs(x = 'Risk (standard deviation)', y = 'Expected return')

# save what the Shiny app needs
dir.create('app', showWarnings = FALSE)
saveRDS(tibble(max_loss = sim$max_loss, stock = rets[, 'stock'], bond = rets[, 'bond']),
        'app/sim_data.rds')
saveRDS(list(a = unname(coef(fit_mkt)[1]), b = unname(coef(fit_mkt)[2]), rf = rf),
        'app/mkt_coef.rds')

# ---- extra tail checks ----
c(without = cvar(port_without, 0.01), with = cvar(port_with, 0.01))   # 1% CVaR

w10    <- c(stock = 0.54, bond = 0.36, cat = 0.10)                    # realistic 10% allocation
port10 <- rets %*% w10
c(sharpe = (mean(port10) - rf) / sd(port10),
  cvar5  = cvar(port10, 0.05),
  cvar1  = cvar(port10, 0.01))