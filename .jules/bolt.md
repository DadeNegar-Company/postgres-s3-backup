## 2025-10-27 - Pipeline Reliability and Streaming
**Learning:** In bash scripts, pipelines like `pg_dump | gzip` will by default return the exit code of the last command (`gzip`). This can lead to silent failures where a database dump fails but the script continues as if it succeeded. Adding `set -o pipefail` is critical for both correctness and performance (as it allows failing fast).
**Action:** Always use `set -o pipefail` when refactoring file-based pipelines into streaming pipelines to ensure that errors anywhere in the stream are correctly caught.
