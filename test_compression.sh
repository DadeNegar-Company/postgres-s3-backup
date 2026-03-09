#!/bin/bash
set -e

# Setup mock environment
export POSTGRES_USER="test_user"
export POSTGRES_PASSWORD="test_password"
export S3_BUCKET="test_bucket"
export POSTGRES_DB="test_db"

export MOCK_CALLS_LOG="/tmp/mock_calls.log"
> "$MOCK_CALLS_LOG"

echo "Running backup.sh with mock PATH binaries..."

TEMP_DIR=$(mktemp -d)
echo 'echo "MOCK_PIGZ"' > "$TEMP_DIR/pigz"
echo 'echo "MOCK_GZIP"' > "$TEMP_DIR/gzip"
echo 'echo "MOCK_PG_DUMP"' > "$TEMP_DIR/pg_dump"
echo 'echo "MOCK_AWS"' > "$TEMP_DIR/aws"
chmod +x "$TEMP_DIR"/*

# Save original path
ORIGINAL_PATH="$PATH"

# Test 1: with pigz
export PATH="$TEMP_DIR:$ORIGINAL_PATH"
echo "--- Test 1: pigz available ---"
./backup.sh > /tmp/backup_output1.log
if grep -q "Using pigz for parallel compression." /tmp/backup_output1.log; then
    echo "PASS: Detected pigz"
else
    echo "FAIL: Did not detect pigz"
    cat /tmp/backup_output1.log
    exit 1
fi

# Test 2: without pigz
rm "$TEMP_DIR/pigz"
echo "--- Test 2: pigz unavailable ---"
./backup.sh > /tmp/backup_output2.log
if grep -q "pigz not found, using gzip for compression." /tmp/backup_output2.log; then
    echo "PASS: Detected gzip fallback"
else
    echo "FAIL: Did not fallback to gzip"
    cat /tmp/backup_output2.log
    exit 1
fi

rm -rf "$TEMP_DIR"
echo "All tests passed!"
