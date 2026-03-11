## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2026-03-11 - [Use pigz for Parallel Compression]
**Learning:** `gzip` is single-threaded, which can create a bottleneck when compressing large database dumps. `pigz` uses parallel threads and can significantly speed up compression on multi-core systems. Additionally, static dependency checks (like `command -v pigz`) should be evaluated once outside loops to avoid redundant execution overhead.
**Action:** Replace `gzip` with `pigz` where available for large compressions. Extract static command availability checks outside loops to configure pipeline tools efficiently.
