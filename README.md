# R/DuckDB TPCH Benchmark

Benchmark script for running TPCH queries on DuckDB with configurable thread count.

## Requirements

- R
- `duckdb` R package
- A DuckDB database with TPCH data loaded

## Usage

```bash
Rscript benchmark.R <database_path> [threads]
```

- `database_path` - Path to a DuckDB database file with TPCH data
- `threads` - (Optional) Number of threads to use. If omitted, uses DuckDB's default.

### Examples

```bash
# Use DuckDB's default thread count
Rscript benchmark.R /path/to/tpch.duckdb

# Use 4 threads
Rscript benchmark.R /path/to/tpch.duckdb 4

# Use 1 thread (single-threaded)
Rscript benchmark.R /path/to/tpch.duckdb 1
```

## Output

The script runs all 22 TPCH queries (`PRAGMA tpch(1)` through `PRAGMA tpch(22)`) and displays timing for each:

| Column | Description |
|--------|-------------|
| Query | Query number (1-22) |
| User | CPU time in user mode (seconds) |
| System | CPU time in kernel mode (seconds) |
| Elapsed | Wall clock time (seconds) |
| CPU/Elapsed | Ratio of total CPU time to elapsed time |

The **CPU/Elapsed** ratio indicates parallelization:
- `1.0` = single-threaded execution
- `> 1.0` = multiple cores utilized (e.g., `4.0` means ~4 cores worth of CPU time)

### Example output

```
DuckDB TPCH Benchmark
Database: /path/to/tpch.duckdb
Threads: 8

Query       User     System   Elapsed  CPU/Elapsed
-----     ------     ------   -------  -----------
1          0.450      0.120     0.180         3.2
2          0.230      0.080     0.095         3.3
...
22         0.180      0.040     0.070         3.1
-----     ------     ------   -------  -----------
TOTAL      8.450      1.230     3.500         2.8
```

## Creating a TPCH Database

To generate a TPCH database for benchmarking:

```sql
-- In DuckDB CLI
INSTALL tpch;
LOAD tpch;
CALL dbgen(sf=1);  -- Scale factor 1 = ~1GB of data
```
