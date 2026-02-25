#!/bin/bash
set -e

# Reset PATH to avoid pollution from previous runs in the same session
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Setup mocks
MOCK_DIR=$(mktemp -d)
export PATH="$MOCK_DIR:$PATH"

# Mock pg_dump
cat << 'EOF' > "$MOCK_DIR/pg_dump"
#!/bin/bash
echo "pg_dump called"
EOF
chmod +x "$MOCK_DIR/pg_dump"

# Mock aws
cat << 'EOF' > "$MOCK_DIR/aws"
#!/bin/bash
cat > /dev/null
echo "aws called"
EOF
chmod +x "$MOCK_DIR/aws"

# Mock gzip
cat << 'EOF' > "$MOCK_DIR/gzip"
#!/bin/bash
cat
echo "gzip called" >> "$MOCK_DIR/gzip_called"
EOF
chmod +x "$MOCK_DIR/gzip"

# Mock psql (for BACKUP_ALL_DATABASES=true case, if needed, but we can test with POSTGRES_DB)
cat << 'EOF' > "$MOCK_DIR/psql"
#!/bin/bash
echo "test_db"
EOF
chmod +x "$MOCK_DIR/psql"

# Test 1: pigz is available
echo "TEST 1: pigz available"
cat << 'EOF' > "$MOCK_DIR/pigz"
#!/bin/bash
cat
echo "pigz called" >> "$MOCK_DIR/pigz_called"
EOF
chmod +x "$MOCK_DIR/pigz"

export POSTGRES_USER="user"
export POSTGRES_PASSWORD="password"
export S3_BUCKET="bucket"
export S3_ACCESS_KEY_ID="key"
export S3_SECRET_ACCESS_KEY="secret"
export POSTGRES_DB="db1"

# Run backup script (assuming run from repo root)
OUTPUT=$(./backup.sh 2>&1)
echo "$OUTPUT"

if echo "$OUTPUT" | grep -q "Using pigz for parallel compression"; then
    echo "PASS: Detected pigz"
else
    echo "FAIL: Did not detect pigz"
    exit 1
fi

# Test 2: pigz is NOT available
echo "TEST 2: pigz NOT available"
rm "$MOCK_DIR/pigz"

# Run backup script
OUTPUT=$(./backup.sh 2>&1)
echo "$OUTPUT"

if echo "$OUTPUT" | grep -q "pigz not found, falling back to gzip"; then
    echo "PASS: Detected missing pigz"
else
    echo "FAIL: Did not detect missing pigz"
    exit 1
fi

rm -rf "$MOCK_DIR"
echo "All tests passed!"
