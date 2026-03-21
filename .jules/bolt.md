## 2024-05-22 - [Streaming Backups to S3]
**Learning:** Streaming `pg_dump` to `aws s3 cp` avoids local disk I/O and space limits, but introduces a silent failure risk if `aws s3 cp` masks upstream errors. `set -o pipefail` is critical to ensure the script fails if `pg_dump` fails, preventing corrupted/partial backups from being marked as successful.
**Action:** Always enable `set -o pipefail` when piping commands where exit codes matter, especially for backups.

## 2024-10-25 - [Use pigz and static pre-calculation]
**Learning:** `pg_dump | gzip` creates a CPU bottleneck where `gzip` is single-threaded and slows down backup of large databases. Using `pigz` utilizes multiple cores for parallel compression without sacrificing script behavior. Additionally, dynamically setting variables inside a loop causes redundant processing. Pre-calculating variables outside the loop improves efficiency without affecting logic.
**Action:** Replace `gzip` with a dynamically evaluated parallel tool like `pigz` and fall back gracefully, while optimizing the loop to only handle database-specific variables.
