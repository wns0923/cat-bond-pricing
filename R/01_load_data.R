# 01_load_data.R
# Loads the three raw data files, checks them, and saves clean copies
# for the later scripts.

library(tidyverse)
library(janitor)

# ---- 1. Hurricane losses (NOAA NCEI Billion-Dollar Disasters) ------------

raw <- read_csv("data/raw/events.csv", skip = 2, show_col_types = FALSE) |>
  clean_names()

hurr <- raw |>
  filter(disaster == "Tropical Cyclone") |>
  transmute(
    name,
    year    = as.integer(substr(as.character(begin_date), 1, 4)),
    loss_bn = cpi_adjusted_cost / 1000     # file is in $ millions -> $ billions
  ) |>
  arrange(year, desc(loss_bn))

# Checks: stop with an error if something is clearly wrong
stopifnot(
  !anyNA(hurr$loss_bn),
  min(hurr$year) == 1980,
  max(hurr$year) == 2024
)
message("Hurricane events loaded: ", nrow(hurr))      # expect 67

print(hurr |> arrange(desc(loss_bn)) |> head(5))      # Katrina should be ~201

# How many events survive at different thresholds?
thresholds <- tibble(u = c(1, 2, 3, 5, 8, 10, 15, 20)) |>
  mutate(n_events = map_int(u, \(x) sum(hurr$loss_bn > x)))
print(thresholds)

# ---- 2. Market returns (Damodaran) ---------------------------------------
mk <- read_csv("data/raw/market_returns.csv", show_col_types = FALSE) |>
  mutate(year = as.integer(year))

stopifnot(
  nrow(mk) == 45,
  identical(mk$year, 1980:2024),
  all(abs(mk$sp500) < 1)                 # decimals (0.12), not percents (12)
)
message("Market years loaded: ", nrow(mk))           
print(mk |> filter(year %in% c(2008, 2022)))          

# ---- 3. Cat bond benchmarks (Artemis) ------------------------------------
bench <- read_csv("data/raw/benchmarks.csv", show_col_types = FALSE)

stopifnot(
  all(c("el_pct", "spread_pct") %in% names(bench)),
  !anyNA(bench$el_pct), !anyNA(bench$spread_pct),
  all(bench$spread_pct > bench$el_pct)   # spread should exceed expected loss
)
message("Benchmark tranches loaded: ", nrow(bench))    # expect 38
print(summary(bench$el_pct))

# ---- 4. Save clean copies ------------------------------------------------
dir.create("data/clean", showWarnings = FALSE, recursive = TRUE)
saveRDS(hurr,  "data/clean/hurr.rds")
saveRDS(mk,    "data/clean/mk.rds")
saveRDS(bench, "data/clean/bench.rds")
message("Saved clean data to data/clean/")
