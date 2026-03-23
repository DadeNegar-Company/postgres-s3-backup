## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - xargs Quote Stripping and Filename Injection
**Vulnerability:** `xargs` was used to trim whitespace from database names, but it also strips quotes (e.g., `db'name` -> `dbname`), leading to backup failures. Additionally, unsanitized database names (e.g., `db/name`) could alter S3 key structures.
**Learning:** `xargs` parses quotes and backslashes by default, making it unsuitable for processing raw strings. Unsanitized inputs used in filenames can lead to path traversal or unexpected file locations.
**Prevention:** Avoid `xargs` for string manipulation; use `sed` or bash parameter expansion. Always sanitize user-influenced inputs before using them in file paths or object keys.

## 2024-05-20 - [Unexported Environment Secrets]
**Vulnerability:** Shell scripts that load secrets from files or environment variables globally (`export VAR=...`) cause those secrets to be inherited by the environment of *all* child processes executed by the script (e.g., `pigz`, `psql`, `aws`). This exposes sensitive credentials unnecessarily and risks leaking them if a child process dumps its environment (e.g., in a crash log or diagnostic output).
**Learning:** Even if a secret is only intended for one specific command in a pipeline, if it exists in the exported environment, all parts of the pipeline and other executed tools get access to it.
**Prevention:** Use `export -n VAR_NAME` immediately after loading or declaring secrets to unexport them from the general environment. The script itself can still access the variables locally and pass them explicitly and exclusively to the specific commands that need them (e.g., `PGPASSWORD="$VAR" pg_dump ...`).
