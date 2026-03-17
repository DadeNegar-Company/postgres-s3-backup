#!/bin/bash

set -e

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

export PATH="$TMP_DIR:$PATH"
export POSTGRES_USER="test_user"
export POSTGRES_PASSWORD="test_password"
export S3_BUCKET="test_bucket"
export S3_ACCESS_KEY_ID="test_key"
export S3_SECRET_ACCESS_KEY="test_secret"
export POSTGRES_DB="test_db"

export LOG_FILE="$TMP_DIR/log.txt"
> "$LOG_FILE"

# Create mock executables
cat << 'EOF' > "$TMP_DIR/pg_dump"
#!/bin/bash
echo "pg_dump called" >> "$LOG_FILE"
echo "data"
EOF
chmod +x "$TMP_DIR/pg_dump"

cat << 'EOF' > "$TMP_DIR/gzip"
#!/bin/bash
echo "gzip called" >> "$LOG_FILE"
cat
EOF
chmod +x "$TMP_DIR/gzip"

cat << 'EOF' > "$TMP_DIR/aws"
#!/bin/bash
echo "aws called" >> "$LOG_FILE"
cat > /dev/null
EOF
chmod +x "$TMP_DIR/aws"

# Test 1: Without pigz
echo "Running test without pigz..."
./backup.sh > "$TMP_DIR/output1.log" 2>&1 || { echo "backup.sh failed"; cat "$TMP_DIR/output1.log"; exit 1; }

echo "Output of backup.sh for test 1:"
cat "$TMP_DIR/output1.log"

if ! grep -q "gzip called" "$LOG_FILE"; then
  echo "Test failed: gzip was not called"
  exit 1
fi
if grep -q "pigz called" "$LOG_FILE"; then
  echo "Test failed: pigz was called when it shouldn't be"
  exit 1
fi

echo "Test 1 (without pigz) passed."
> "$LOG_FILE"

# Test 2: With pigz
cat << 'EOF' > "$TMP_DIR/pigz"
#!/bin/bash
echo "pigz called" >> "$LOG_FILE"
cat
EOF
chmod +x "$TMP_DIR/pigz"

echo "Running test with pigz..."
./backup.sh > "$TMP_DIR/output2.log" 2>&1 || { echo "backup.sh failed"; cat "$TMP_DIR/output2.log"; exit 1; }

if grep -q "gzip called" "$LOG_FILE"; then
  echo "Test failed: gzip was called instead of pigz"
  exit 1
fi
if ! grep -q "pigz called" "$LOG_FILE"; then
  echo "Test failed: pigz was not called"
  exit 1
fi

echo "Test 2 (with pigz) passed."
echo "All tests passed successfully."
