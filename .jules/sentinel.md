## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - xargs Quote Stripping and Filename Injection
**Vulnerability:** `xargs` was used to trim whitespace from database names, but it also strips quotes (e.g., `db'name` -> `dbname`), leading to backup failures. Additionally, unsanitized database names (e.g., `db/name`) could alter S3 key structures.
**Learning:** `xargs` parses quotes and backslashes by default, making it unsuitable for processing raw strings. Unsanitized inputs used in filenames can lead to path traversal or unexpected file locations.
**Prevention:** Avoid `xargs` for string manipulation; use `sed` or bash parameter expansion. Always sanitize user-influenced inputs before using them in file paths or object keys.

## 2026-02-28 - Secret Exposure via Environment Variables
**Vulnerability:** The script exported `PGPASSWORD=$POSTGRES_PASSWORD` which exposes the cleartext database password to any local user via the `ps` command (e.g., `ps e` or looking at `/proc/PID/environ`).
**Learning:** Environment variables are often globally visible on a system and may be unintentionally logged by process monitoring tools or child processes.
**Prevention:** Avoid passing secrets via environment variables when native, secure configuration files exist. For PostgreSQL, use a `PGPASSFILE` pointing to a securely created, restricted (`chmod 0600`) temporary file that is automatically cleaned up on exit (e.g., via `trap`). Ensure special characters (`\` and `:`) in passwords are properly escaped when writing to the passfile.
