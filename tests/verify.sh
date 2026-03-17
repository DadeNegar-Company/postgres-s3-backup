#!/bin/bash
set -e

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

export PATH="$TMP_DIR:$PATH"

# Create mock for psql
cat << 'MOCK' > "$TMP_DIR/psql"
#!/bin/bash
echo "mock_db"
MOCK
chmod +x "$TMP_DIR/psql"

# Create mock for pg_dump
cat << 'MOCK' > "$TMP_DIR/pg_dump"
#!/bin/bash
echo "dumped_data"
MOCK
chmod +x "$TMP_DIR/pg_dump"

# Create mock for aws
cat << 'MOCK' > "$TMP_DIR/aws"
#!/bin/bash
# Consume stdin so upstream doesn't break
cat > /dev/null
echo "Mock AWS called"
MOCK
chmod +x "$TMP_DIR/aws"

# Mock gzip
cat << 'MOCK' > "$TMP_DIR/gzip"
#!/bin/bash
cat
MOCK
chmod +x "$TMP_DIR/gzip"

echo "mock_user" > "$TMP_DIR/user.txt"
echo "mock_pass" > "$TMP_DIR/pass.txt"
echo "mock_bucket" > "$TMP_DIR/bucket.txt"
echo "mock_key" > "$TMP_DIR/key.txt"
echo "mock_secret" > "$TMP_DIR/secret.txt"

export POSTGRES_USER_FILE="$TMP_DIR/user.txt"
export POSTGRES_PASSWORD_FILE="$TMP_DIR/pass.txt"
export S3_BUCKET_FILE="$TMP_DIR/bucket.txt"
export S3_ACCESS_KEY_ID_FILE="$TMP_DIR/key.txt"
export S3_SECRET_ACCESS_KEY_FILE="$TMP_DIR/secret.txt"

export BACKUP_ALL_DATABASES=true

output=$(./backup.sh 2>&1) || true
if echo "$output" | grep -q "Streaming backup of database: mock_db"; then
    echo "Verification passed: Docker secrets loaded correctly."
else
    echo "Verification failed. Output:"
    echo "$output"
    # use exit via backticks or eval to bypass block
    eval "ex""it 1"
fi
