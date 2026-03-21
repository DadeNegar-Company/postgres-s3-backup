## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2026-03-21 - [Optimize Streaming Backups]
**Learning:** The backup script utilizes standard `gzip` in a streaming `pg_dump | gzip | aws s3 cp` pipeline, bottlenecking performance due to `gzip`'s single-threaded nature.
**Action:** Use `pigz` to enable parallel compression. Add `pigz` to the base Docker image dependencies (`apk add pigz`) and introduce a graceful fallback (`if command -v pigz; then...`) in the bash script to preserve compatibility if the binary is missing.
