#!/usr/bin/env Rscript

# DuckDB TPCH Benchmark Script
# Usage: Rscript benchmark.R <database_path> [threads]

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 1) {
  cat("Usage: Rscript benchmark.R <database_path> [threads]\n")
  cat("Example: Rscript benchmark.R /path/to/tpch.duckdb 4\n")
  quit(status = 1)
}

db_path <- args[1]
num_threads <- if (length(args) >= 2) as.integer(args[2]) else NULL

if (!is.null(num_threads) && (is.na(num_threads) || num_threads < 1)) {
  cat("Error: threads must be a positive integer\n")
  quit(status = 1)
}

if (!file.exists(db_path)) {
  cat(sprintf("Error: database file not found: %s\n", db_path))
  quit(status = 1)
}

library(duckdb)

con <- dbConnect(duckdb(), dbdir = db_path, read_only = TRUE)
on.exit(dbDisconnect(con, shutdown = TRUE))

if (!is.null(num_threads)) {
  dbExecute(con, sprintf("PRAGMA threads=%d", num_threads))
}

actual_threads <- dbGetQuery(con, "SELECT current_setting('threads')")[[1]]

cat("\nDuckDB TPCH Benchmark\n")
cat(sprintf("Database: %s\n", db_path))
cat(sprintf("Threads: %s\n\n", actual_threads))

results <- data.frame(
  query = integer(),
  user = numeric(),
  system = numeric(),
  elapsed = numeric()
)

cat(sprintf("%-7s %10s %10s %10s %10s\n", "Query", "User", "System", "Elapsed", "CPU/Elapsed"))
cat(sprintf("%-7s %10s %10s %10s %10s\n", "-----", "------", "------", "-------", "-----------"))

for (q in 1:22) {
  timing <- system.time({
    invisible(dbGetQuery(con, sprintf("PRAGMA tpch(%d)", q)))
  })
  results <- rbind(results, data.frame(
    query = q,
    user = timing["user.self"],
    system = timing["sys.self"],
    elapsed = timing["elapsed"]
  ))
  cpu_total <- timing["user.self"] + timing["sys.self"]
  ratio <- if (timing["elapsed"] > 0) cpu_total / timing["elapsed"] else 0
  cat(sprintf("%-7d %10.3f %10.3f %10.3f %10.1f\n", q, timing["user.self"], timing["sys.self"], timing["elapsed"], ratio))
}

totals <- data.frame(
  query = NA,
  user = sum(results$user),
  system = sum(results$system),
  elapsed = sum(results$elapsed)
)

cat(sprintf("%-7s %10s %10s %10s %10s\n", "-----", "------", "------", "-------", "-----------"))
cpu_total <- totals$user + totals$system
ratio <- if (totals$elapsed > 0) cpu_total / totals$elapsed else 0
cat(sprintf("%-7s %10.3f %10.3f %10.3f %10.1f\n", "TOTAL", totals$user, totals$system, totals$elapsed, ratio))
