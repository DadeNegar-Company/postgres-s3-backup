## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2026-03-08 - [Parallel Compression Pipeline]
**Learning:** Compressing database backups with standard `gzip` in a pipeline (`pg_dump | gzip | aws`) is single-threaded and bottlenecks on large databases, increasing backup time significantly. Also, resolving dependencies like `command -v` inside loops causes redundant checks.
**Action:** Replace `gzip` with `pigz` (parallel gzip) in pipelines to utilize multiple CPU cores for faster compression. Always evaluate dependency checks outside of loops to prevent redundant execution and improve efficiency, ensuring graceful fallbacks.
