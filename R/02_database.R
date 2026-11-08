# 02_database.R
library(tidyverse); library(DBI); library(RSQLite)

hurr  <- readRDS('data/clean/hurr.rds')
mk    <- readRDS('data/clean/mk.rds')
bench <- readRDS('data/clean/bench.rds')

con <- dbConnect(SQLite(), 'data/clean/catbond.sqlite')

# drop old tables so the script can be re-run safely
for (t in c('events', 'market_returns', 'benchmarks', 'sim_runs', 'sim_years', 'tranches', 'results')) {
  dbExecute(con, paste0('DROP TABLE IF EXISTS ', t))
}

dbExecute(con, 'CREATE TABLE events (event_id INTEGER PRIMARY KEY, name TEXT, year INTEGER, loss_bn REAL)')
dbExecute(con, 'CREATE TABLE market_returns (year INTEGER PRIMARY KEY, sp500 REAL, tbill REAL, tbond10 REAL)')
dbExecute(con, 'CREATE TABLE sim_runs (run_id INTEGER PRIMARY KEY, n_years INTEGER, lambda REAL, sigma REAL, xi REAL, threshold REAL, cap REAL, seed INTEGER)')
dbExecute(con, 'CREATE TABLE sim_years (run_id INTEGER, sim_year INTEGER, n_events INTEGER, max_loss_bn REAL, agg_loss_bn REAL, PRIMARY KEY (run_id, sim_year))')
dbExecute(con, 'CREATE TABLE tranches (tranche_id INTEGER PRIMARY KEY, name TEXT, attach_rp REAL, exhaust_rp REAL, attach_bn REAL, exhaust_bn REAL)')
dbExecute(con, 'CREATE TABLE results (run_id INTEGER, tranche_id INTEGER, el REAL, p_attach REAL, p_exhaust REAL, spread REAL)')

dbWriteTable(con, 'events', hurr |> mutate(event_id = row_number()) |> select(event_id, name, year, loss_bn), append = TRUE)
dbWriteTable(con, 'market_returns', mk, append = TRUE)
dbWriteTable(con, 'benchmarks', bench)

dbGetQuery(con, 'SELECT COUNT(*) AS n FROM events')   # expect 67
dbDisconnect(con)