## 2026-02-23 - Command Injection in backup.sh via eval
**Vulnerability:** Use of `eval` with unvalidated environment variables (`S3_BUCKET`, `S3_PREFIX`, `POSTGRES_DB`, `S3_ENDPOINT`) allowed for arbitrary command execution.
**Learning:** The `eval` command is dangerous when used with input that can be influenced by users or external systems. In bash, optional arguments can be handled safely using arrays instead of building a command string for `eval`.
**Prevention:** Avoid `eval` whenever possible. Use bash arrays for dynamic command arguments and always quote variables to prevent word splitting and globbing. Use `--` to signal the end of command options when passing variables that might start with a hyphen.

## 2026-02-23 - S3 Key Path Traversal
**Vulnerability:** Unsanitized database names used in S3 object keys could allow path traversal or unintended directory structures in S3 buckets.
**Learning:** Always sanitize user input or external data (like database names) before using them in file paths or object keys, to ensure predictable naming and prevent traversal.
**Prevention:** Use parameter expansion like `${var//\//_}` to replace dangerous characters (like slashes) with safe ones (like underscores).
