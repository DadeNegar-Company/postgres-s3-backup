## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - xargs Quote Stripping and Filename Injection
**Vulnerability:** `xargs` was used to trim whitespace from database names, but it also strips quotes (e.g., `db'name` -> `dbname`), leading to backup failures. Additionally, unsanitized database names (e.g., `db/name`) could alter S3 key structures.
**Learning:** `xargs` parses quotes and backslashes by default, making it unsuitable for processing raw strings. Unsanitized inputs used in filenames can lead to path traversal or unexpected file locations.
**Prevention:** Avoid `xargs` for string manipulation; use `sed` or bash parameter expansion. Always sanitize user-influenced inputs before using them in file paths or object keys.

## 2026-03-07 - Insecure Database Name Parsing via `echo` Command Flags
**Vulnerability:** Use of `echo "$db"` to trim whitespace and sanitize database names caused a data-loss bug when a database was named exactly like an `echo` flag (e.g., `-e` or `-n`), resulting in silent failure as `echo` produced empty output.
**Learning:** `echo` is fundamentally unsafe for processing unvalidated user strings because it parses flags before evaluating the string, leading to unpredictable edge cases with arbitrary string inputs.
**Prevention:** Always use `printf "%s\n" "$VAR"` instead of `echo "$VAR"` when manipulating variables or printing content that might contain unexpected characters or begin with hyphens.

## 2026-03-07 - Avoid `.pgpass` on Disk for Environment Secret Mitigation
**Vulnerability:** Exporting `PGPASSWORD` leaks credentials into the environment (visible to `docker inspect`, `/proc`, and crash dumps). Mitigating this by writing `.pgpass` securely to `/tmp` was rejected due to a cleartext-on-disk vulnerability if the script crashed before the `EXIT` trap ran.
**Learning:** For Docker container scripts, do not attempt to mitigate environment variable leakage by writing secrets to disk. Instead, the correct pattern is to implement support for reading directly from mounted Docker Secrets (`_FILE` variables like `POSTGRES_PASSWORD_FILE`), which avoids the environment entirely while keeping secrets out of persistent storage.
**Prevention:** Add standard logic `if [ -f "$SECRET_FILE" ]; then SECRET=$(cat "$SECRET_FILE"); fi` to read credentials directly into memory. Do not introduce cleartext disk writes as a workaround for environment variable leakage.
