## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2026-03-09 - [Parallel Compression for Streaming Backups]
**Learning:** For streaming database backups where CPU is not the primary bottleneck, single-threaded tools like `gzip` can limit backup speed, particularly as database size grows. Using a parallel compressor like `pigz` can utilize multiple cores, dramatically accelerating the backup process with a simple drop-in pipeline replacement.
**Action:** When compressing large streams or files (like `pg_dump` outputs) in a multi-core environment, always check for and prefer `pigz` over standard `gzip` to optimize performance, providing a fallback if the tool is not installed.
