#!/usr/bin/env Rscript

# DuckDB TPCH Benchmark Script with mirai parallel execution
# Usage: Rscript benchmark.R <database_path> [threads] [daemons]

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 1) {
  cat("Usage: Rscript benchmark.R <database_path> [threads] [daemons]\n")
  cat("  threads: DuckDB threads per daemon (default: auto)\n")
  cat("  daemons: number of mirai daemons for parallel queries (default: 1, sequential)\n")
  cat("Example: Rscript benchmark.R /path/to/tpch.duckdb 4 8\n")
  quit(status = 1)
}

db_path <- args[1]
num_threads <- if (length(args) >= 2) as.integer(args[2]) else NULL
if (is.na(num_threads)) num_threads <- NULL # Treat "NA" as default
num_daemons <- if (length(args) >= 3) as.integer(args[3]) else 1L

if (!is.null(num_threads) && num_threads < 1) {
  cat("Error: threads must be a positive integer\n")
  quit(status = 1)
}

if (is.na(num_daemons) || num_daemons < 1) {
  cat("Error: daemons must be a positive integer\n")
  quit(status = 1)
}

if (!file.exists(db_path)) {
  cat(sprintf("Error: database file not found: %s\n", db_path))
  quit(status = 1)
}

library(duckdb)
library(mirai)

# Get actual threads setting for display
con <- dbConnect(duckdb(), dbdir = db_path, read_only = TRUE)
if (!is.null(num_threads)) {
  dbExecute(con, sprintf("PRAGMA threads=%d", num_threads))
}
actual_threads <- dbGetQuery(con, "SELECT current_setting('threads')")[[1]]
dbDisconnect(con, shutdown = TRUE)

cat("\nDuckDB TPCH Benchmark (mirai)\n")
cat(sprintf("Database: %s\n", db_path))
cat(sprintf("Threads per daemon: %s\n", actual_threads))
cat(sprintf("Daemons: %d\n\n", num_daemons))

# Start mirai daemons
daemons(num_daemons)
on.exit(daemons(0), add = TRUE)

# Function to run a single query in a daemon
run_query <- function(q, db_path, num_threads) {
  library(duckdb)
  con <- dbConnect(duckdb(), dbdir = db_path, read_only = TRUE)
  on.exit(dbDisconnect(con, shutdown = TRUE))

  if (!is.null(num_threads)) {
    dbExecute(con, sprintf("PRAGMA threads=%d", num_threads))
  }

  timing <- system.time({
    invisible(dbGetQuery(con, sprintf("PRAGMA tpch(%d)", q)))
  })

  list(
    query = q,
    user = timing["user.self"],
    system = timing["sys.self"],
    elapsed = timing["elapsed"]
  )
}

# Submit all queries as mirai tasks
cat("Submitting 22 queries to mirai daemons...\n\n")
wall_start <- Sys.time()
tasks <- lapply(1:22, function(q) {
  mirai(run_query(q, db_path, num_threads),
    q = q, db_path = db_path, num_threads = num_threads,
    run_query = run_query
  )
})

# Collect results
results_list <- lapply(tasks, function(m) m[])
wall_elapsed <- as.numeric(difftime(Sys.time(), wall_start, units = "secs"))

# Build results data frame
results <- do.call(rbind, lapply(results_list, function(r) {
  data.frame(
    query = r$query,
    user = r$user,
    system = r$system,
    elapsed = r$elapsed
  )
}))

# Sort by query number
results <- results[order(results$query), ]

cat(sprintf("%-7s %10s %10s %10s %10s\n", "Query", "User", "System", "Elapsed", "CPU/Elapsed"))
cat(sprintf("%-7s %10s %10s %10s %10s\n", "-----", "------", "------", "-------", "-----------"))

for (i in seq_len(nrow(results))) {
  r <- results[i, ]
  cpu_total <- r$user + r$system
  ratio <- if (r$elapsed > 0) cpu_total / r$elapsed else 0
  cat(sprintf("%-7d %10.3f %10.3f %10.3f %10.1f\n", r$query, r$user, r$system, r$elapsed, ratio))
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

cat(sprintf("\nWall clock time: %.3f seconds\n", wall_elapsed))
cat(sprintf("Speedup vs sequential: %.2fx\n", totals$elapsed / wall_elapsed))
