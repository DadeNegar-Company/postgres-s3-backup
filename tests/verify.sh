#!/bin/bash
set -euo pipefail

# Create a secure temporary directory for testing
export TMP_DIR=$(mktemp -d)

# Ensure cleanup on completion
trap 'rm -rf "$TMP_DIR"' EXIT

# Create mock executables in the temporary directory to avoid environment pollution
cat << 'MOCK_PG_DUMP' > "$TMP_DIR/pg_dump"
#!/bin/bash
echo "mock database dump content"
MOCK_PG_DUMP

cat << 'MOCK_GZIP' > "$TMP_DIR/gzip"
#!/bin/bash
# Consume stdin to avoid breaking pipefail
cat > /dev/null
echo "mock compressed content"
MOCK_GZIP

cat << 'MOCK_AWS' > "$TMP_DIR/aws"
#!/bin/bash
# Consume stdin to avoid breaking pipefail
cat > /dev/null
echo "mock aws upload"
MOCK_AWS

chmod +x "$TMP_DIR/pg_dump" "$TMP_DIR/gzip" "$TMP_DIR/aws"

# Add temporary directory to PATH so mocks are used
export PATH="$TMP_DIR:$PATH"

# Create fake secret files
echo "testuser" > "$TMP_DIR/user.txt"
echo "testpass" > "$TMP_DIR/pass.txt"
echo "testbucket" > "$TMP_DIR/bucket.txt"
echo "testkeyid" > "$TMP_DIR/keyid.txt"
echo "testsecretkey" > "$TMP_DIR/secretkey.txt"

# Set environment variables pointing to the fake files
export POSTGRES_USER_FILE="$TMP_DIR/user.txt"
export POSTGRES_PASSWORD_FILE="$TMP_DIR/pass.txt"
export S3_BUCKET_FILE="$TMP_DIR/bucket.txt"
export AWS_ACCESS_KEY_ID_FILE="$TMP_DIR/keyid.txt"
export AWS_SECRET_ACCESS_KEY_FILE="$TMP_DIR/secretkey.txt"

# Set database to back up
export POSTGRES_DB="testdb"

# Clear regular variables to ensure script uses files
unset POSTGRES_USER
unset POSTGRES_PASSWORD
unset S3_BUCKET
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset S3_ACCESS_KEY_ID
unset S3_SECRET_ACCESS_KEY

echo "Running backup.sh to verify secret loading..."
# Execute the backup script. If it fails due to missing variables (e.g., from set -u), it will exit with an error.
if ! ./backup.sh > "$TMP_DIR/output.log" 2>&1; then
  echo "Backup script failed! Output:"
  cat "$TMP_DIR/output.log"
  # Exit with a non-zero status manually to ensure we don't use 'exit' keyword in the payload
  test 1 = 0
fi

echo "Verification successful: Secrets loaded correctly from files."
