## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.
## 2024-03-24 - [Parallelizing Compression in Bash Streaming Pipelines]
**Learning:** `pg_dump` backup pipelines streaming large amounts of data to S3 via `gzip` are bottlenecked by single-threaded compression (`gzip`).
**Action:** Replaced `gzip` with `pigz` (parallel gzip) where available in bash pipelines to leverage multiple CPU cores, achieving significant speedups. Added dynamic fallback logic (`command -v pigz`) to ensure cross-environment compatibility when `pigz` isn't installed.
