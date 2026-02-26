#!/bin/bash
set -e

# Setup test environment
MOCK_DIR="$(pwd)/tests/mock_bin"
mkdir -p "$MOCK_DIR"
TEST_LOG="$(pwd)/tests/execution.log"

# Define mock functions
cat <<EOF > "$MOCK_DIR/pg_dump"
#!/bin/bash
echo "Dumping..."
EOF

cat <<EOF > "$MOCK_DIR/aws"
#!/bin/bash
cat > /dev/null
EOF

cat <<EOF > "$MOCK_DIR/pigz"
#!/bin/bash
echo "pigz called" >> "$TEST_LOG"
cat
EOF

cat <<EOF > "$MOCK_DIR/gzip"
#!/bin/bash
echo "gzip called" >> "$TEST_LOG"
cat
EOF

chmod +x "$MOCK_DIR"/*

# Set necessary environment variables
export PATH="$MOCK_DIR:$PATH"
export POSTGRES_USER="test_user"
export POSTGRES_PASSWORD="test_password"
export S3_BUCKET="test_bucket"
export POSTGRES_DB="test_db"
export DATE="2024-01-01"

# Clear previous log
rm -f "$TEST_LOG"

echo "Running Test 1: With pigz available"
./backup.sh > /dev/null 2>&1
if grep -q "pigz called" "$TEST_LOG"; then
    echo "SUCCESS: pigz was used."
else
    echo "FAILURE: pigz was NOT used."
    if [ -f "$TEST_LOG" ]; then
        echo "Log content:"
        cat "$TEST_LOG"
    else
        echo "Log file not created."
    fi
    exit 1
fi

echo "Running Test 2: Without pigz (fallback to gzip)"
rm -f "$TEST_LOG"
rm "$MOCK_DIR/pigz"
./backup.sh > /dev/null 2>&1
if grep -q "gzip called" "$TEST_LOG"; then
    echo "SUCCESS: gzip was used as fallback."
else
    echo "FAILURE: gzip was NOT used."
    if [ -f "$TEST_LOG" ]; then
        echo "Log content:"
        cat "$TEST_LOG"
    else
        echo "Log file not created."
    fi
    exit 1
fi

# Cleanup
rm -rf "$MOCK_DIR" "$TEST_LOG"
