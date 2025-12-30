# R/DuckDB TPCH Benchmark

Benchmark script for running TPCH queries on DuckDB with configurable thread count and parallel query execution using mirai.

## Requirements

- R
- `duckdb` R package
- `mirai` R package
- A DuckDB database with TPCH data loaded

## Usage

```bash
Rscript benchmark.R <database_path> [threads] [daemons]
```

- `database_path` - Path to a DuckDB database file with TPCH data
- `threads` - (Optional) Number of DuckDB threads per daemon. If omitted, uses DuckDB's default.
- `daemons` - (Optional) Number of mirai daemons for parallel query execution. Default: 1 (sequential).

### Examples

```bash
# Sequential execution with DuckDB's default thread count
Rscript benchmark.R /path/to/tpch.duckdb

# 4 DuckDB threads, sequential query execution
Rscript benchmark.R /path/to/tpch.duckdb 4

# 4 DuckDB threads per daemon, 8 parallel daemons
Rscript benchmark.R /path/to/tpch.duckdb 4 8

# Default DuckDB threads, 22 parallel daemons (one per query)
Rscript benchmark.R /path/to/tpch.duckdb NA 22
```

## Output

The script runs all 22 TPCH queries (`PRAGMA tpch(1)` through `PRAGMA tpch(22)`) using mirai daemons and displays timing for each:

| Column | Description |
|--------|-------------|
| Query | Query number (1-22) |
| User | CPU time in user mode (seconds) |
| System | CPU time in kernel mode (seconds) |
| Elapsed | Elapsed time per query (seconds) |
| CPU/Elapsed | Ratio of total CPU time to elapsed time |

The **CPU/Elapsed** ratio indicates DuckDB parallelization within each query:
- `1.0` = single-threaded execution
- `> 1.0` = multiple cores utilized (e.g., `4.0` means ~4 cores worth of CPU time)

At the end, the script reports:
- **Wall clock time** - Actual elapsed time from start to finish
- **Speedup vs sequential** - Ratio of summed query times to wall clock time (shows parallel execution benefit)

### Example output

```
DuckDB TPCH Benchmark (mirai)
Database: /path/to/tpch.duckdb
Threads per daemon: 4
Daemons: 8

Submitting 22 queries to mirai daemons...

Query       User     System   Elapsed  CPU/Elapsed
-----     ------     ------   -------  -----------
1          0.450      0.120     0.180         3.2
2          0.230      0.080     0.095         3.3
...
22         0.180      0.040     0.070         3.1
-----     ------     ------   -------  -----------
TOTAL      8.450      1.230     3.500         2.8

Wall clock time: 1.250 seconds
Speedup vs sequential: 2.80x
```

## Creating a TPCH Database

To generate a TPCH database for benchmarking:

```sql
-- In DuckDB CLI
INSTALL tpch;
LOAD tpch;
CALL dbgen(sf=1);  -- Scale factor 1 = ~1GB of data
```
