# 08_uncertainty_validation.R
library(tidyverse); library(evd)
source('R/functions.R')
hurr     <- readRDS('data/clean/hurr.rds')
p        <- readRDS('data/clean/params.rds')
tranches <- readRDS('data/clean/tranches.rds')

# ---- 8a. bootstrap (about a minute or two) ----
boot_once <- function(b) {
  yrs <- sample(1980:2024, replace = TRUE)
  ev  <- map_dfr(yrs, function(y) filter(hurr, year == y))
  x_b <- ev$loss_bn[ev$loss_bn > p$u]
  fit <- tryCatch(fpot(x_b, threshold = p$u, std.err = FALSE), error = function(e) NULL)
  if (is.null(fit)) return(NULL)
  s <- simulate_years(20000, length(x_b) / 45, fit$estimate['scale'],
                      fit$estimate['shape'], p$u, p$cap)
  tranches |> rowwise() |>
    mutate(EL = mean(pmin(1, pmax(0, (s$max_loss - attach_bn) / (exhaust_bn - attach_bn)))),
           boot = b) |>
    ungroup() |> select(boot, name, EL)
}
set.seed(11)
boot <- map_dfr(1:1000, boot_once)
boot |> group_by(name) |>
  summarise(lo = quantile(EL, 0.05), med = median(EL), hi = quantile(EL, 0.95))

# ---- 8b. backtest: fit through 2009, test on 2010-2024 ----
train  <- hurr |> filter(year <= 2009)
test   <- hurr |> filter(year >= 2010)
fit_tr <- fpot(train$loss_bn, threshold = p$u)
lam_tr <- sum(train$loss_bn > p$u) / 30
big    <- 30        # choose so the predicted count is about 2 to 3
pred   <- 15 * lam_tr * (1 - pgpd(big, loc = p$u, scale = fit_tr$estimate['scale'],
                                  shape = fit_tr$estimate['shape']))
c(predicted = unname(pred), actual = sum(test$loss_bn > big))

# ---- 8c. sensitivity: threshold and cap ----
run_case <- function(u, cap) {
  x   <- hurr$loss_bn
  fit <- fpot(x, threshold = u, std.err = FALSE)
  lam <- sum(x > u) / 45
  s   <- simulate_years(50000, lam, fit$estimate['scale'], fit$estimate['shape'], u, cap, seed = 1)
  mezz <- filter(tranches, name == 'Mezzanine')
  tibble(u = u, cap = cap, xi = unname(fit$estimate['shape']),
         EL = mean(pmin(1, pmax(0, (s$max_loss - mezz$attach_bn) / (mezz$exhaust_bn - mezz$attach_bn)))))
}
grid <- expand_grid(u = c(3, 5, 8), cap = c(300, 500, 1000))
pmap_dfr(grid, run_case)

# ---- 8d. sensitivity: recent event rate (frequency may have risen) ----
mezz <- filter(tranches, name == 'Mezzanine')
for (start in c(1980, 2000, 2010)) {
  lam <- sum(hurr$loss_bn > p$u & hurr$year >= start) / (2024 - start + 1)
  s   <- simulate_years(100000, lam, p$sigma, p$xi, p$u, p$cap, seed = 1)
  el  <- mean(pmin(1, pmax(0, (s$max_loss - mezz$attach_bn) / (mezz$exhaust_bn - mezz$attach_bn))))
  print(c(start = start, lambda = round(lam, 3), EL = round(el, 4)))
}