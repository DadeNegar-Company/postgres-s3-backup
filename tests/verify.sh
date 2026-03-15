#!/bin/bash
set -e
set -o pipefail

# Create a secure temporary directory
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Created TMP_DIR: $TMP_DIR"

# Mock required binaries
cat << 'EOF' > "$TMP_DIR/pg_dump"
#!/bin/bash
echo "mock_db_dump_content"
EOF

cat << 'EOF' > "$TMP_DIR/gzip"
#!/bin/bash
cat
EOF

cat << 'EOF' > "$TMP_DIR/aws"
#!/bin/bash
# Consume stdin to prevent SIGPIPE in previous pipeline commands
cat > /dev/null
echo "mock aws args: $@"
EOF

cat << 'EOF' > "$TMP_DIR/psql"
#!/bin/bash
echo "mock_db1"
echo "mock_db2"
EOF

chmod +x "$TMP_DIR/pg_dump" "$TMP_DIR/gzip" "$TMP_DIR/aws" "$TMP_DIR/psql"

# Prepend mock directory to PATH
export PATH="$TMP_DIR:$PATH"

# Create mock secret files
echo "secret_user" > "$TMP_DIR/user.txt"
echo "secret_password" > "$TMP_DIR/password.txt"
echo "secret_bucket" > "$TMP_DIR/bucket.txt"
echo "secret_access_key" > "$TMP_DIR/access_key.txt"
echo "secret_secret_key" > "$TMP_DIR/secret_key.txt"
echo "mydb1,mydb2" > "$TMP_DIR/dbs.txt"

# Set _FILE environment variables
export POSTGRES_USER_FILE="$TMP_DIR/user.txt"
export POSTGRES_PASSWORD_FILE="$TMP_DIR/password.txt"
export S3_BUCKET_FILE="$TMP_DIR/bucket.txt"
export S3_ACCESS_KEY_ID_FILE="$TMP_DIR/access_key.txt"
export S3_SECRET_ACCESS_KEY_FILE="$TMP_DIR/secret_key.txt"
export POSTGRES_DB_FILE="$TMP_DIR/dbs.txt"

# Run the backup script in a subshell, capturing output
OUTPUT=$(bash ./backup.sh 2>&1)

echo "$OUTPUT"

# Verify that the correct secrets were loaded and passed to aws cli
if echo "$OUTPUT" | grep -q "Streaming backup of database: mydb1 to s3://secret_bucket/"; then
  echo "SUCCESS: Found correct s3 destination for mydb1."
else
  echo "FAIL: Did not find expected s3 destination for mydb1 in output."
  exit 1
fi

if echo "$OUTPUT" | grep -q "Streaming backup of database: mydb2 to s3://secret_bucket/"; then
  echo "SUCCESS: Found correct s3 destination for mydb2."
else
  echo "FAIL: Did not find expected s3 destination for mydb2 in output."
  exit 1
fi

echo "All tests passed successfully."
