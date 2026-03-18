#!/bin/bash
set -e
set -o pipefail
set -u

# Temporary scratchpad directory
export TMP_DIR=$(mktemp -d)

# Exit trap to clean up scratchpad directory
trap 'rm -rf "$TMP_DIR"' EXIT

# Create mock executables in the temporary directory to mimic external commands
export PATH="$TMP_DIR:$PATH"

cat << 'MOCK' > "$TMP_DIR/pg_dump"
#!/bin/bash
echo "mock_pg_dump output for $@"
MOCK
chmod +x "$TMP_DIR/pg_dump"

cat << 'MOCK' > "$TMP_DIR/gzip"
#!/bin/bash
cat
MOCK
chmod +x "$TMP_DIR/gzip"

cat << 'MOCK' > "$TMP_DIR/aws"
#!/bin/bash
# Consume stdin to prevent SIGPIPE in upstream pipeline
cat > /dev/null
echo "mock_aws output for $@"
MOCK
chmod +x "$TMP_DIR/aws"

cat << 'MOCK' > "$TMP_DIR/psql"
#!/bin/bash
echo "mock_db"
MOCK
chmod +x "$TMP_DIR/psql"

echo "secret_user" > "$TMP_DIR/user.txt"
echo "secret_password" > "$TMP_DIR/password.txt"
echo "secret_bucket" > "$TMP_DIR/bucket.txt"

export POSTGRES_USER_FILE="$TMP_DIR/user.txt"
export POSTGRES_PASSWORD_FILE="$TMP_DIR/password.txt"
export S3_BUCKET_FILE="$TMP_DIR/bucket.txt"
export POSTGRES_DB="testdb"

export S3_ACCESS_KEY_ID_FILE="$TMP_DIR/missing_key.txt"
export S3_SECRET_ACCESS_KEY_FILE="$TMP_DIR/missing_secret.txt"

# Run backup.sh and capture output
OUTPUT=$(./backup.sh)

# Assertions
if ! echo "$OUTPUT" | grep -q "Streaming backup of database: testdb to s3://secret_bucket/testdb_"; then
  echo "Test failed: S3 bucket or database name not correctly parsed."
  echo "Output was:"
  echo "$OUTPUT"
  exit 1
fi

if ! echo "$OUTPUT" | grep -q "Backup process completed successfully."; then
  echo "Test failed: Backup did not complete successfully."
  echo "Output was:"
  echo "$OUTPUT"
  exit 1
fi

echo "Tests passed successfully!"
