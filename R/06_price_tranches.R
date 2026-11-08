# 06_price_tranches.R
library(tidyverse); library(DBI); library(RSQLite)
source('R/functions.R')
sim   <- readRDS('data/clean/sim.rds')
p     <- readRDS('data/clean/params.rds')
bench <- readRDS('data/clean/bench.rds')

q <- function(t) quantile(sim$max_loss, 1 - 1 / t, names = FALSE)
tranches <- tribble(
  ~name,       ~attach_rp, ~exhaust_rp,
  'Junior',    20,         50,
  'Mezzanine', 50,         100,
  'Senior',    100,        250
) |>
  mutate(attach_bn  = round(map_dbl(attach_rp, q)),
         exhaust_bn = round(map_dbl(exhaust_rp, q)))
stopifnot(all(tranches$attach_bn > p$u))   # cannot attach below the modeled region
tranches

# risk numbers for each tranche
tranche_results <- tranches |> rowwise() |>
  mutate(stats = list(tranche_stats(sim$max_loss, attach_bn, exhaust_bn))) |>
  ungroup() |> unnest(stats)

# market line: log(spread) = a + b * log(EL), fitted on the Artemis benchmarks
fit_mkt <- lm(log(spread_pct) ~ log(el_pct), data = bench)
summary(fit_mkt)

tranche_results <- tranche_results |>
  mutate(spread   = map_dbl(EL, function(e) predict_spread(e, fit_mkt)),
         multiple = spread / EL)
tranche_results

# are your tranches inside the benchmark range?
range(bench$el_pct); range(tranche_results$EL * 100)

ggplot(bench, aes(el_pct, spread_pct)) + geom_point() +
  geom_point(data = tranche_results, aes(EL * 100, spread * 100), color = 'red', size = 3) +
  scale_x_log10() + scale_y_log10() +
  labs(x = 'Expected loss (%)', y = 'Spread (%)')

saveRDS(tranches, 'data/clean/tranches.rds')
saveRDS(tranche_results, 'data/clean/tranche_results.rds')
saveRDS(fit_mkt, 'data/clean/fit_mkt.rds')

con <- dbConnect(SQLite(), 'data/clean/catbond.sqlite')
dbExecute(con, 'DELETE FROM tranches'); dbExecute(con, 'DELETE FROM results')
dbWriteTable(con, 'tranches', tranches |> mutate(tranche_id = row_number()) |>
               select(tranche_id, name, attach_rp, exhaust_rp, attach_bn, exhaust_bn), append = TRUE)
dbWriteTable(con, 'results', tranche_results |> mutate(run_id = 1L, tranche_id = row_number()) |>
               select(run_id, tranche_id, el = EL, p_attach, p_exhaust, spread), append = TRUE)
dbDisconnect(con)