## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - xargs Quote Stripping and Filename Injection
**Vulnerability:** `xargs` was used to trim whitespace from database names, but it also strips quotes (e.g., `db'name` -> `dbname`), leading to backup failures. Additionally, unsanitized database names (e.g., `db/name`) could alter S3 key structures.
**Learning:** `xargs` parses quotes and backslashes by default, making it unsuitable for processing raw strings. Unsanitized inputs used in filenames can lead to path traversal or unexpected file locations.
**Prevention:** Avoid `xargs` for string manipulation; use `sed` or bash parameter expansion. Always sanitize user-influenced inputs before using them in file paths or object keys.

## 2026-03-03 - Database Password Exposure via Environment Variables
**Vulnerability:** The database password was being exported directly as `PGPASSWORD` in the environment (`export PGPASSWORD=$POSTGRES_PASSWORD`), which exposes it to other processes or debugging output running in the same environment.
**Learning:** Hardcoding or directly exporting sensitive database passwords into environment variables during script execution presents a severe risk of information leakage, especially when they can be unintentionally captured by debug logs or subprocesses.
**Prevention:** Always use secure credentials files (like `PGPASSFILE` for PostgreSQL) with strict permissions (`0600`) to authenticate securely instead of passing passwords via environment variables. Ensure these files are temporarily created securely and properly removed using a `trap` for guaranteed cleanup upon script termination.
