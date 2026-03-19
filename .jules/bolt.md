## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2026-03-19 - [Parallel Compression & Caching Checks]
**Learning:** Standard `gzip` only utilizes a single CPU core. In streaming pipelines handling large database dumps (e.g., `pg_dump | gzip`), compression often becomes the bottleneck. Additionally, executing `command -v` checks inside a loop adds redundant overhead.
**Action:** Replace `gzip` with `pigz` (parallel gzip) to utilize multiple CPU cores and accelerate streaming pipelines. Always evaluate dependencies (like `command -v pigz`) outside of loops to cache the result in a variable (e.g., `COMPRESS_CMD`) and improve execution efficiency.
