## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - xargs Quote Stripping and Filename Injection
**Vulnerability:** `xargs` was used to trim whitespace from database names, but it also strips quotes (e.g., `db'name` -> `dbname`), leading to backup failures. Additionally, unsanitized database names (e.g., `db/name`) could alter S3 key structures.
**Learning:** `xargs` parses quotes and backslashes by default, making it unsuitable for processing raw strings. Unsanitized inputs used in filenames can lead to path traversal or unexpected file locations.
**Prevention:** Avoid `xargs` for string manipulation; use `sed` or bash parameter expansion. Always sanitize user-influenced inputs before using them in file paths or object keys.

## 2026-02-23 - Cleartext Credentials on Disk Avoidance (Docker Secrets)
**Vulnerability:** Scripts often require sensitive data like passwords and access keys. Writing these directly to temporary files on disk or forcing them to be injected via environment variables (which can be visible in process listings or logs) increases exposure risk.
**Learning:** Docker Secrets provides a mechanism to map sensitive files into the container. Using a `*_FILE` environment variable pattern (e.g., `POSTGRES_PASSWORD_FILE`) allows a script to read the credential directly into memory at runtime securely. A helper function `file_env` can check for `*_FILE` presence using native bash `[[ -v "$var" ]]` arrays instead of risky indirect variable expansion like `${!var:-}`.
**Prevention:** Avoid writing cleartext credentials to files during script execution. If external secrets are needed, read them securely from Docker Secrets via `*_FILE` paths directly into memory variables at runtime.
