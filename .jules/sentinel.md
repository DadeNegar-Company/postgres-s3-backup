## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - xargs Quote Stripping and Filename Injection
**Vulnerability:** `xargs` was used to trim whitespace from database names, but it also strips quotes (e.g., `db'name` -> `dbname`), leading to backup failures. Additionally, unsanitized database names (e.g., `db/name`) could alter S3 key structures.
**Learning:** `xargs` parses quotes and backslashes by default, making it unsuitable for processing raw strings. Unsanitized inputs used in filenames can lead to path traversal or unexpected file locations.
**Prevention:** Avoid `xargs` for string manipulation; use `sed` or bash parameter expansion. Always sanitize user-influenced inputs before using them in file paths or object keys.

## 2026-02-23 - Docker Secrets Pattern for Credentials
**Vulnerability:** Cleartext credentials (passwords, access keys) were being passed directly as environment variables (`POSTGRES_PASSWORD`, `S3_ACCESS_KEY_ID`, etc.), which can be exposed through logs, process listings (`ps`), or container inspection tools.
**Learning:** Containerized applications should support loading sensitive information securely from files mounted into the container (e.g., Docker Secrets or Kubernetes Secrets).
**Prevention:** Implement a pattern to read credentials from files specified by `*_FILE` environment variables. Ensure the process mutually excludes cleartext and file-based variables to avoid ambiguity. Provide graceful errors for missing files or misconfigurations.
