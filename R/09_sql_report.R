# 09_sql_report.R
library(DBI); library(RSQLite)
con <- dbConnect(SQLite(), 'data/clean/catbond.sqlite')

run_sql <- function(file) dbGetQuery(con, paste(readLines(file), collapse = ' '))
run_sql('sql/tranche_stats.sql')
run_sql('sql/worst_years.sql')
run_sql('sql/mezz_buckets.sql')

dbGetQuery(con, 'SELECT * FROM results')   # compare with the first query
dbDisconnect(con)