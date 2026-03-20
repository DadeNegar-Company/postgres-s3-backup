## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2024-05-20 - Parallelize Compression in Streaming Backups
**Learning:** Streaming backups (`pg_dump | gzip | aws`) are CPU-bound on compression, causing bottlenecks on multi-core environments. Standard `gzip` only uses a single core.
**Action:** Replace `gzip` with `pigz` (parallel implementation of gzip) in the pipeline to utilize multiple cores. Always check for availability (`command -v pigz`) and fall back to `gzip` to ensure compatibility across diverse execution environments.
