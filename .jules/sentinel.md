## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - Path Traversal in backup filenames
**Vulnerability:** Unsanitized database names used in filenames allowed for path traversal (e.g., `../sensitive_file`) when writing backups.
**Learning:** Always sanitize user input or external data (like database names) before using them in file paths, even if the source seems trusted.
**Prevention:** Use parameter expansion like `${var//\//_}` to replace dangerous characters (like slashes) with safe ones (like underscores) in filenames.

## 2026-02-23 - Silent Backup Failure due to missing pipefail
**Vulnerability:** `pg_dump | gzip` pipeline would return success even if `pg_dump` failed, leading to zero-byte/corrupted backups being uploaded.
**Learning:** By default, bash pipelines return the exit code of the last command. In a backup script, every step must succeed.
**Prevention:** Always use `set -o pipefail` in bash scripts where the success of the entire pipeline is critical.
