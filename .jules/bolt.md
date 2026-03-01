## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2024-05-19 - Parallel Compression
**Learning:** `pg_dump` can produce a very large volume of data, and standard `gzip` compression is single-threaded, which can bottleneck the entire backup pipeline (`pg_dump | gzip | aws`).
**Action:** Use `pigz` (parallel gzip) for compression in streaming backup pipelines to utilize multiple CPU cores, falling back to `gzip` if `pigz` is not installed.
