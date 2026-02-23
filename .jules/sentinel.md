## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - Path Traversal in backup.sh via POSTGRES_DB
**Vulnerability:** User-provided database names were used directly in filenames for temporary files in `/tmp`, allowing for path traversal (e.g., `../../../etc/passwd`).
**Learning:** Even when command injection is fixed, user input used in file paths must be sanitized to prevent writing to or overwriting arbitrary files.
**Prevention:** Sanitize all user input used in file paths. Replace or remove directory separators (like `/`). Additionally, use `set -o pipefail` to ensure that failures in a pipeline (like `pg_dump | gzip`) are correctly caught by `set -e`.
