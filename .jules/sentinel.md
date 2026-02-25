## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - xargs Quote Stripping and Filename Injection
**Vulnerability:** `xargs` was used to trim whitespace from database names, but it also strips quotes (e.g., `db'name` -> `dbname`), leading to backup failures. Additionally, unsanitized database names (e.g., `db/name`) could alter S3 key structures.
**Learning:** `xargs` parses quotes and backslashes by default, making it unsuitable for processing raw strings. Unsanitized inputs used in filenames can lead to path traversal or unexpected file locations.
**Prevention:** Avoid `xargs` for string manipulation; use `sed` or bash parameter expansion. Always sanitize user-influenced inputs before using them in file paths or object keys.

## 2026-02-25 - Credential Leakage via Process Environment
**Vulnerability:** Use of `export PGPASSWORD` exposed database credentials in the process environment, which can be visible to other users or processes (e.g., via `ps eww` or `/proc`).
**Learning:** Environment variables are not a secure way to pass sensitive secrets to child processes if process isolation is not guaranteed. `PGPASSFILE` offers a file-based alternative with strict permission checks (`0600`).
**Prevention:** Use `.pgpass` files for PostgreSQL credentials. Ensure the file is created with `mktemp`, has `0600` permissions, and is cleaned up via `trap`. Use `printf` instead of `echo` to safely handle special characters and avoid newline issues when writing secrets to files.
