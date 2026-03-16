## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - xargs Quote Stripping and Filename Injection
**Vulnerability:** `xargs` was used to trim whitespace from database names, but it also strips quotes (e.g., `db'name` -> `dbname`), leading to backup failures. Additionally, unsanitized database names (e.g., `db/name`) could alter S3 key structures.
**Learning:** `xargs` parses quotes and backslashes by default, making it unsuitable for processing raw strings. Unsanitized inputs used in filenames can lead to path traversal or unexpected file locations.
**Prevention:** Avoid `xargs` for string manipulation; use `sed` or bash parameter expansion. Always sanitize user-influenced inputs before using them in file paths or object keys.

## 2026-03-16 - Prevent Credential Exposure using Docker Secrets
**Vulnerability:** The script previously required passing database credentials (`POSTGRES_USER`, `POSTGRES_PASSWORD`) and cloud credentials (`S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`) strictly via environment variables. In containerized environments, environment variables can be inspected easily by external tooling or read through `/proc`, making them a risky place for secrets.
**Learning:** Using Docker Secrets (loading credentials from files dynamically mapped into the container, typically under `/run/secrets/`) is a best practice. The script can securely support both by reading from file pathways passed via environment variables (e.g., `POSTGRES_PASSWORD_FILE`), loading them securely at runtime into memory variables, reducing attack surface vectors.
**Prevention:** Support Docker Secrets or similar file-based secret injection natively rather than forcing standard environment variable exposure for highly sensitive details. Read secrets securely at runtime instead of writing them to temporary files on disk.
