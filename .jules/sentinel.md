## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - xargs Quote Stripping and Filename Injection
**Vulnerability:** `xargs` was used to trim whitespace from database names, but it also strips quotes (e.g., `db'name` -> `dbname`), leading to backup failures. Additionally, unsanitized database names (e.g., `db/name`) could alter S3 key structures.
**Learning:** `xargs` parses quotes and backslashes by default, making it unsuitable for processing raw strings. Unsanitized inputs used in filenames can lead to path traversal or unexpected file locations.
**Prevention:** Avoid `xargs` for string manipulation; use `sed` or bash parameter expansion. Always sanitize user-influenced inputs before using them in file paths or object keys.

## 2026-03-12 - Missing Docker Secrets Support
**Vulnerability:** The application originally required sensitive credentials (`POSTGRES_PASSWORD`, `S3_SECRET_ACCESS_KEY`) to be provided as explicit environment variables, which can leak into logs, container metadata, and process lists.
**Learning:** Docker Secrets (via `_FILE` environment variables) provide a secure mechanism to mount credentials. However, scripts must process these correctly. Writing the secret from the file into an intermediate temporary file (e.g., `.pgpass` in `/tmp`) creates a risk of orphaned credentials if the script crashes before cleanup traps execute.
**Prevention:** Support `_FILE` environment variables by reading their contents directly into memory variables at runtime using `export "$var_name"="$(head -n 1 "$file_var_val" | tr -d '\r')"` rather than creating temporary credential files.
