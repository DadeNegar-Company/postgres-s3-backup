## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2026-03-13 - Parallel Gzip Compression
**Learning:** Using standard `gzip` in backup pipelines bounds the compression throughput to a single CPU core, creating a bottleneck for large database dumps. `pigz` functions as a drop-in replacement that utilizes multiple cores for compression.
**Action:** When compressing large streams, always check for `pigz` (`command -v pigz`) to enable parallel processing while falling back to `gzip` gracefully.
