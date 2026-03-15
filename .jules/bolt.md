## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2026-03-15 - [Parallel Compression]
**Learning:** Standard gzip runs synchronously and only on a single CPU core, leading to bottlenecks during large database backup stream compression pipelines.
**Action:** Detect and use pigz, a parallel implementation of gzip, outside the iteration loop for efficient compression while safely falling back to gzip.
