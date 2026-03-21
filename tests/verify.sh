#!/bin/bash

set -e

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

export PATH="$TMP_DIR:$PATH"
export CALLED_COMPRESS_CMD=""

# Create mock pg_dump
cat << 'EOF' > "$TMP_DIR/pg_dump"
#!/bin/bash
echo "mock database dump content"
EOF
chmod +x "$TMP_DIR/pg_dump"

# Create mock psql
cat << 'EOF' > "$TMP_DIR/psql"
#!/bin/bash
echo "mockdb"
EOF
chmod +x "$TMP_DIR/psql"

# Create mock aws
cat << 'EOF' > "$TMP_DIR/aws"
#!/bin/bash
# Consume stdin to avoid SIGPIPE
cat > /dev/null
echo "mock aws upload called"
EOF
chmod +x "$TMP_DIR/aws"

# We will export log files for our assertions
export PIGZ_LOG="$TMP_DIR/pigz_called"
export GZIP_LOG="$TMP_DIR/gzip_called"

# Create mock pigz
cat << 'EOF' > "$TMP_DIR/pigz"
#!/bin/bash
touch "$PIGZ_LOG"
cat > /dev/null
EOF
chmod +x "$TMP_DIR/pigz"

# Create mock gzip
cat << 'EOF' > "$TMP_DIR/gzip"
#!/bin/bash
touch "$GZIP_LOG"
cat > /dev/null
EOF
chmod +x "$TMP_DIR/gzip"


echo "Test 1: Run backup.sh with pigz available in PATH"

# set required variables
export POSTGRES_USER="test_user"
export POSTGRES_PASSWORD="test_password"
export S3_BUCKET="test_bucket"
export S3_ACCESS_KEY_ID="test_key"
export S3_SECRET_ACCESS_KEY="test_secret"
export BACKUP_ALL_DATABASES="false"
export POSTGRES_DB="testdb"

./backup.sh >/dev/null

if [ ! -f "$PIGZ_LOG" ]; then
    echo "FAILED: pigz was not called during backup when it was available."
    exit 1
fi
echo "PASSED: pigz was called."

# Reset for next test
rm -f "$PIGZ_LOG" "$GZIP_LOG"
rm "$TMP_DIR/pigz" # Remove pigz to fallback to gzip

echo "Test 2: Run backup.sh with pigz unavailable in PATH (should use gzip)"
./backup.sh >/dev/null

if [ ! -f "$GZIP_LOG" ]; then
    echo "FAILED: gzip was not called during backup when pigz was absent."
    exit 1
fi
echo "PASSED: gzip was called as fallback."

echo "All tests passed successfully!"
