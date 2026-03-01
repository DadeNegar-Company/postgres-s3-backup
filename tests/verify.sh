#!/bin/bash

set -e

# Create a temporary directory for mocks
MOCK_DIR=$(mktemp -d)
LOG_FILE="$MOCK_DIR/execution.log"

# Cleanup function
cleanup() {
  rm -rf "$MOCK_DIR"
}
trap cleanup EXIT

# Mock scripts
cat << 'EOF' > "$MOCK_DIR/pg_dump"
#!/bin/bash
echo "pg_dump called with: $@" >> "$LOG_FILE"
echo "dummy db data"
EOF

cat << 'EOF' > "$MOCK_DIR/aws"
#!/bin/bash
echo "aws called with: $@" >> "$LOG_FILE"
cat > /dev/null
EOF

cat << 'EOF' > "$MOCK_DIR/pigz"
#!/bin/bash
echo "pigz called with: $@" >> "$LOG_FILE"
cat
EOF

cat << 'EOF' > "$MOCK_DIR/gzip"
#!/bin/bash
echo "gzip called with: $@" >> "$LOG_FILE"
cat
EOF

chmod +x "$MOCK_DIR"/pg_dump "$MOCK_DIR"/aws "$MOCK_DIR"/pigz "$MOCK_DIR"/gzip

# Prepend mock directory to PATH
export PATH="$MOCK_DIR:$PATH"
export LOG_FILE

# Test environment variables
export POSTGRES_USER="testuser"
export POSTGRES_PASSWORD="testpassword"
export S3_BUCKET="test-bucket"
export POSTGRES_DB="testdb"

# Run the backup script
bash ./backup.sh

# Verify the execution log
echo "--- Execution Log ---"
cat "$LOG_FILE"
echo "---------------------"

if grep -q "pigz called" "$LOG_FILE"; then
  echo "SUCCESS: pigz was called."
else
  echo "FAILURE: pigz was NOT called."
  exit 1
fi

if grep -q "gzip called" "$LOG_FILE"; then
  echo "FAILURE: gzip was called, but pigz should have been used."
  exit 1
else
  echo "SUCCESS: gzip was not called."
fi
