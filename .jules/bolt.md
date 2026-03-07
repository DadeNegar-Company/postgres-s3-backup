## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2024-05-23 - [Parallel Database Dump Compression]
**Learning:** Standard `gzip` only uses a single CPU core, which can be a significant bottleneck during large database backups, slowing down the entire `pg_dump | gzip | aws s3 cp` pipeline.
**Action:** Use `pigz` (parallel gzip) when available to utilize multiple CPU cores for compression. Always fall back to `gzip` if `pigz` is missing to ensure robustness across different environments. In bash scripts, evaluate the availability of `pigz` (`command -v pigz`) once, outside of any loops, to avoid redundant command execution.
