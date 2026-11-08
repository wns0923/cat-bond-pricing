# 05_simulate.R
library(tidyverse); library(DBI); library(RSQLite)
source('R/functions.R')
p    <- readRDS('data/clean/params.rds')
hurr <- readRDS('data/clean/hurr.rds')

sim <- simulate_years(100000, p$lambda, p$sigma, p$xi, p$u, p$cap, seed = 2024)
saveRDS(sim, 'data/clean/sim.rds')

# validate: simulated exceedance curve vs historical (red dots)
hist_max <- hurr |> filter(loss_bn > p$u) |> group_by(year) |> summarise(m = max(loss_bn)) |>
  right_join(tibble(year = 1980:2024), by = 'year') |> replace_na(list(m = 0)) |>
  arrange(desc(m)) |> mutate(rp = (n() + 1) / row_number())
sim_ep <- sim |> arrange(desc(max_loss)) |> mutate(rp = (n() + 1) / row_number()) |>
  filter(max_loss > 0)

ggplot() +
  geom_line(data = sim_ep, aes(rp, max_loss)) +
  geom_point(data = filter(hist_max, m > 0), aes(rp, m), color = 'red') +
  scale_x_log10() + scale_y_log10() +
  labs(x = 'Return period (years)', y = 'Largest hurricane loss (USD billions)')

# save the run to the database
con <- dbConnect(SQLite(), 'data/clean/catbond.sqlite')
dbExecute(con, 'DELETE FROM sim_runs WHERE run_id = 1')
dbExecute(con, 'DELETE FROM sim_years WHERE run_id = 1')
dbExecute(con, 'INSERT INTO sim_runs VALUES (1, 100000, ?, ?, ?, ?, ?, 2024)',
          params = list(p$lambda, p$sigma, p$xi, p$u, p$cap))
dbWriteTable(con, 'sim_years',
             sim |> transmute(run_id = 1L, sim_year, n_events,
                              max_loss_bn = max_loss, agg_loss_bn = agg_loss),
             append = TRUE)
dbDisconnect(con)