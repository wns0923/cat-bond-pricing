# 04_severity_frequency.R
library(tidyverse); library(evd)
hurr <- readRDS('data/clean/hurr.rds')
x <- hurr$loss_bn

# 1. choose the threshold u
mrlplot(x)                          # mean residual life plot
tcplot(x, tlim = c(1.5, 20))        # shape and scale vs threshold (two panels)
u <- 5                              # REPLACE with your own choice from the plots
sum(x > u)                          # keep at least 25-30

# 2. severity: fit the GPD above u
fit_gpd <- fpot(x, threshold = u)
fit_gpd$estimate
fit_gpd$std.err
plot(fit_gpd)                       # 4 diagnostic plots: points should hug the lines
sigma <- unname(fit_gpd$estimate['scale'])
xi    <- unname(fit_gpd$estimate['shape'])
cap   <- 500                        # cap on simulated losses (USD billions); test later

# 3. frequency: events above u per year, including zero years
counts <- hurr |> filter(loss_bn > u) |> count(year) |>
  complete(year = 1980:2024, fill = list(n = 0))
c(mean = mean(counts$n), var = var(counts$n))   # Poisson: mean == variance
fit_pois <- MASS::fitdistr(counts$n, 'Poisson')
fit_nb   <- MASS::fitdistr(counts$n, 'negative binomial')
AIC(fit_pois, fit_nb)               # lower is better; under 2 apart means no real difference
lambda <- mean(counts$n)

# 4. save for later scripts
saveRDS(list(u = u, sigma = sigma, xi = xi, lambda = lambda, cap = cap),
        'data/clean/params.rds')