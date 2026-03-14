## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.
## 2024-05-24 - Parallel Compression in Streaming Pipelines
**Learning:** Using `gzip` in a streaming pipeline (e.g., `pg_dump | gzip | aws`) bottlenecks the transfer speed to a single CPU core, underutilizing available resources for large database dumps.
**Action:** Use `pigz` (parallel gzip) as a drop-in replacement for `gzip` to compress streams across multiple cores, and always implement a fallback `command -v pigz` check to ensure the script doesn't fail if the dependency is missing.
