## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2024-06-11 - [Parallel Compression & Static Checks]
**Learning:** Using `pigz` instead of `gzip` utilizes multiple CPU cores and speeds up large database stream backups significantly. Furthermore, checking for binary availability (like `command -v pigz`) inside a loop over databases causes redundant lookup checks. Hoisting the binary check outside the loop improves efficiency.
**Action:** When implementing compression in pipelines, prefer `pigz` but keep `gzip` as a fallback. Always hoist static condition checks or binary lookups outside of iterative loops.
