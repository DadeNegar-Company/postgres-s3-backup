## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2024-05-23 - [Parallel Compression for Streaming Backups]
**Learning:** Using `gzip` in a database backup pipeline (`pg_dump | gzip | aws`) limits compression to a single CPU core, creating a bottleneck for large databases.
**Action:** Replace `gzip` with `pigz` (parallel gzip) where available. It utilizes multiple cores for compression, significantly speeding up the pipeline. Always use `command -v pigz` to implement a fallback to `gzip` if `pigz` is uninstalled to prevent pipeline failures.
