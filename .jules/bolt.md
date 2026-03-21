## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2024-05-23 - [Parallel Compression with pigz]
**Learning:** Using standard `gzip` in a backup pipeline limits compression to a single CPU core, which becomes a significant bottleneck for large databases. By replacing `gzip` with `pigz` (parallel gzip), we can utilize all available CPU cores, dramatically increasing compression speed without changing the output file format.
**Action:** Always prefer `pigz` over `gzip` in backup pipelines for multi-core environments, using `command -v pigz` to fallback gracefully if it's unavailable.
