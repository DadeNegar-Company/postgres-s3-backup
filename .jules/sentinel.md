## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - xargs Quote Stripping and Filename Injection
**Vulnerability:** `xargs` was used to trim whitespace from database names, but it also strips quotes (e.g., `db'name` -> `dbname`), leading to backup failures. Additionally, unsanitized database names (e.g., `db/name`) could alter S3 key structures.
**Learning:** `xargs` parses quotes and backslashes by default, making it unsuitable for processing raw strings. Unsanitized inputs used in filenames can lead to path traversal or unexpected file locations.
**Prevention:** Avoid `xargs` for string manipulation; use `sed` or bash parameter expansion. Always sanitize user-influenced inputs before using them in file paths or object keys.

## 2026-03-06 - PGPASSWORD Environment Variable Leakage
**Vulnerability:** `PGPASSWORD` was exported in the script, making the database password accessible to any child process spawned by the script (e.g., `pg_dump`, `aws`, `gzip`) and potentially visible in process monitoring tools or crash dumps.
**Learning:** Exporting secrets as environment variables (`export PGPASSWORD=$POSTGRES_PASSWORD`) leaks them to the environment of all subsequent commands. Using a `.pgpass` file is the secure mechanism for passing passwords to PostgreSQL client tools. Special characters in passwords (`\` and `:`) must be escaped properly in the `.pgpass` file format.
**Prevention:** Use a securely generated temporary file (`mktemp` with `0600` permissions) as `PGPASSFILE`. Ensure to explicitly `unset` the original password variables (like `POSTGRES_PASSWORD` and `PGPASSWORD`) after writing them to the file. Set a secure `EXIT` trap to delete the temporary file, taking care to append to any existing traps.
