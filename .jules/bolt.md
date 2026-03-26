## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2024-10-25 - [Use pigz and static pre-calculation]
**Learning:** `pg_dump | gzip` creates a CPU bottleneck where `gzip` is single-threaded and slows down backup of large databases. Using `pigz` utilizes multiple cores for parallel compression without sacrificing script behavior. Additionally, dynamically setting variables inside a loop causes redundant processing. Pre-calculating variables outside the loop improves efficiency without affecting logic.
**Action:** Replace `gzip` with a dynamically evaluated parallel tool like `pigz` and fall back gracefully, while optimizing the loop to only handle database-specific variables.

## 2024-10-26 - [Optimize Bash String Manipulation in Loops]
**Learning:** Using `$(echo "$var" | sed '...')` inside loops creates a significant performance bottleneck because Bash forks a subshell and invokes external binaries (`echo`, `sed`) for each iteration. In a benchmark of 1000 iterations, the external subshells took ~7 seconds compared to ~0.05 seconds for Bash built-ins.
**Action:** Replace `echo` + `sed` pattern inside loops with pure Bash parameter expansion. Use `${var#"${var%%[![:space:]]*}"}` and `${var%"${var##*[![:space:]]}"}` for string trimming, and `${var//pattern/replacement}` for character replacement to keep execution in the main process and achieve ~140x speedups.

## 2026-03-26 - [Optimize S3 Multipart Uploads]
**Learning:** The default AWS CLI S3 configuration is not optimized for high-throughput streaming uploads via stdin, limiting bandwidth utilization. Increasing `max_concurrent_requests` and `multipart_chunksize` significantly improves upload speeds for large database dumps.
**Action:** Always tune `default.s3.max_concurrent_requests` and `default.s3.multipart_chunksize` in environments handling large streaming uploads to S3.

## 2026-03-26 - [Safe Bash Traps and Config Files]
**Learning:** When creating temporary configuration files (like `AWS_CONFIG_FILE`), blindly overwriting the path hides existing user configurations. Similarly, defining a new `trap ... EXIT` overwrites prior cleanup logic.
**Action:** Always copy existing configuration files before mutating them, and safely append to existing traps to preserve prior cleanup logic.

## 2024-10-27 - [Optimize Compression Speed for Database Backups]
**Learning:** For database backups, compressing archives often uses excessive CPU cycles, creating a bottleneck. The difference in space savings between default compression and fast compression (`--fast` or `-1`) is generally negligible (e.g., ~1% difference in size for typical datasets) while providing significantly faster backup durations (e.g., ~2-3x speedup on compression speed). Time and CPU utilization are typically more critical than minor space savings on fast networks.
**Action:** When invoking compression binaries like `gzip` or `pigz` in a streaming pipeline, default to prioritizing speed over ratio by using arguments like `--fast` unless strict space requirements dictate otherwise.

## 2024-10-28 - [AWS CLI S3 Upload Optimization]
**Learning:** The default AWS CLI S3 `max_concurrent_requests` (10) and `multipart_chunksize` (8MB) are extremely conservative. When uploading large streaming backups (e.g., from `pg_dump`), this creates an artificial bottleneck. By tuning these parameters, throughput can be significantly improved without changing the architecture.
**Action:** Always tune AWS CLI concurrency settings (`max_concurrent_requests` to ~20 and `multipart_chunksize` to ~64MB) when setting up `aws s3 cp` or `aws s3 sync` for large files or streaming inputs, provided the network has sufficient bandwidth.
