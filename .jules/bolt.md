## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2026-03-02 - [Parallel Compression in Streaming Backups]
**Learning:** Single-threaded `gzip` creates a CPU bottleneck in streaming database backups (`pg_dump | gzip | aws`), slowing down the entire pipeline for large databases because it cannot utilize multiple cores.
**Action:** Replace `gzip` with `pigz` (parallel gzip) when available in the environment to parallelize compression and significantly speed up the backup pipeline.
