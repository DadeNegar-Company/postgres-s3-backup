## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.
## $(date +%Y-%m-%d) - Parallel Compression with pigz
**Learning:** By default, Postgres database dumps use `gzip` in single-core mode, which bottlenecks backup performance on multi-core systems, especially for large databases.
**Action:** Replace `gzip` with `pigz` (parallel gzip) in backup pipelines to significantly reduce compression time by utilizing multiple CPU cores. Always include a static fallback check (`command -v pigz`) outside of processing loops to ensure the script remains robust if the dependency is missing.
