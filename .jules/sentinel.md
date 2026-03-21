## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - xargs Quote Stripping and Filename Injection
**Vulnerability:** `xargs` was used to trim whitespace from database names, but it also strips quotes (e.g., `db'name` -> `dbname`), leading to backup failures. Additionally, unsanitized database names (e.g., `db/name`) could alter S3 key structures.
**Learning:** `xargs` parses quotes and backslashes by default, making it unsuitable for processing raw strings. Unsanitized inputs used in filenames can lead to path traversal or unexpected file locations.
**Prevention:** Avoid `xargs` for string manipulation; use `sed` or bash parameter expansion. Always sanitize user-influenced inputs before using them in file paths or object keys.
## 2024-05-21 - Docker Secrets Support via _FILE env vars
**Vulnerability:** Passing plaintext credentials (e.g., POSTGRES_PASSWORD, S3_ACCESS_KEY_ID) directly via environment variables exposes them to potential leakage (e.g., via `docker inspect` or log outputs) rather than supporting more secure storage options.
**Learning:** Hardcoded environment variables can be substituted safely for `_FILE` alternatives to handle Docker Secrets using standard conventions. In bash scripts, variables like `POSTGRES_PASSWORD_FILE` can be dynamically expanded using indirect references (`${!file_var_name}`) to parse secret files in memory.
**Prevention:** Implement a standard `load_secret` function for reading credentials gracefully using `head -n 1 "$file_path" | tr -d '\r\n'` instead of loading direct env variables blindly.
