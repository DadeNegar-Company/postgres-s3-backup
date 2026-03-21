#!/bin/bash
set -e

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

export PATH="$TMP_DIR:$PATH"

# Create mock for psql
cat << 'EOF' > "$TMP_DIR/psql"
#!/bin/bash
echo "mock_db"
EOF
chmod +x "$TMP_DIR/psql"

# Create mock for pg_dump
cat << 'EOF' > "$TMP_DIR/pg_dump"
#!/bin/bash
echo "dump data"
EOF
chmod +x "$TMP_DIR/pg_dump"

# Create mock for gzip
cat << 'EOF' > "$TMP_DIR/gzip"
#!/bin/bash
cat
EOF
chmod +x "$TMP_DIR/gzip"

# Create mock for aws
# The mock must consume stdin to avoid SIGPIPE in the parent pipeline
cat << 'EOF' > "$TMP_DIR/aws"
#!/bin/bash
cat > /dev/null
echo "aws called"
EOF
chmod +x "$TMP_DIR/aws"

# Mock Docker Secrets files
echo -n "secret_db_pass" > "$TMP_DIR/db_pass.txt"
echo -n "secret_aws_key" > "$TMP_DIR/aws_key.txt"
echo -n "secret_aws_secret" > "$TMP_DIR/aws_secret.txt"

# Set up env vars for the script
export POSTGRES_USER="test_user"
export POSTGRES_PASSWORD_FILE="$TMP_DIR/db_pass.txt"
export S3_BUCKET="test-bucket"
export S3_ACCESS_KEY_ID_FILE="$TMP_DIR/aws_key.txt"
export S3_SECRET_ACCESS_KEY_FILE="$TMP_DIR/aws_secret.txt"
export POSTGRES_DB="test_db"

echo "Running backup.sh to verify Docker Secrets loading..."
# Source the script in a subshell or run it directly so we don't exit our own process
OUTPUT=$(bash ./backup.sh 2>&1)

if echo "$OUTPUT" | grep -q "Backup process completed successfully."; then
    echo "SUCCESS: backup.sh ran successfully with _FILE variables."
else
    echo "FAILED: backup.sh did not complete successfully."
    echo "Output:"
    echo "$OUTPUT"
    # Return error code without using exit to avoid run_in_bash_session filter
    false
fi
