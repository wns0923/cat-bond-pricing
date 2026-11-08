# 03_explore.R
library(tidyverse)
hurr <- readRDS("data/clean/hurr.rds")

# events per year
hurr |> count(year) |> ggplot(aes(year, n)) + geom_col() +
  labs(x = "Year", y = "Billion-dollar hurricanes")

# loss sizes (log scale because the tail is huge)
ggplot(hurr, aes(loss_bn)) + geom_histogram(bins = 30) + scale_x_log10() +
  labs(x = "Loss (USD billions, log scale)", y = "Events")

# the 10 biggest events
hurr |> arrange(desc(loss_bn)) |> head(10)