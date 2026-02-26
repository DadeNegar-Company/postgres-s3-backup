## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2026-02-26 - [Parallel Compression with pigz]
**Learning:** `gzip` is single-threaded and becomes a bottleneck for large database dumps on multi-core systems. Replacing it with `pigz` (Parallel Implementation of GZip) utilizes all available cores, significantly reducing backup time without changing the output format.
**Action:** Use `pigz` for compression in CPU-bound tasks like backups, but always implement a fallback to `gzip` to ensure portability across environments where `pigz` might be missing.
