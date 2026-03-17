## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2024-05-23 - [Parallel Database Backup Compression]
**Learning:** Using `gzip` in a backup pipeline (e.g., `pg_dump | gzip | aws`) creates a bottleneck because `gzip` only utilizes a single CPU core. Database dumps can be large, and CPU compression often bounds the throughput of the stream. Checking for commands like `pigz` inside a `for` loop unnecessarily incurs the overhead of command resolution on every iteration.
**Action:** Use `pigz` (parallel gzip) when available to utilize multiple cores and dramatically speed up large database backups. When conditionally using commands based on availability, evaluate static dependencies (`command -v`) outside loops to prevent redundant execution and improve script efficiency.
