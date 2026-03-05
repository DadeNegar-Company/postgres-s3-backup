## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - xargs Quote Stripping and Filename Injection
**Vulnerability:** `xargs` was used to trim whitespace from database names, but it also strips quotes (e.g., `db'name` -> `dbname`), leading to backup failures. Additionally, unsanitized database names (e.g., `db/name`) could alter S3 key structures.
**Learning:** `xargs` parses quotes and backslashes by default, making it unsuitable for processing raw strings. Unsanitized inputs used in filenames can lead to path traversal or unexpected file locations.
**Prevention:** Avoid `xargs` for string manipulation; use `sed` or bash parameter expansion. Always sanitize user-influenced inputs before using them in file paths or object keys.

## 2026-03-05 - Avoid PGPASSWORD Leakage
**Vulnerability:** The script exported `PGPASSWORD` into the environment, which makes it visible in `ps e` output and any subprocesses, violating secure secret handling practices.
**Learning:** `PGPASSWORD` shouldn't be exported when `PGPASSFILE` can be used securely with a temporary file and appropriate permissions. The originally populated variable must be unset from the script's memory.
**Prevention:** Use a securely created temporary file via `mktemp` with `0600` permissions. Write the password to it in `host:port:database:user:password` format. Clean up the temp file on exit via `trap` and run `unset POSTGRES_PASSWORD`.
