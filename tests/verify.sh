#!/bin/bash
set -e

# Setup temp dir for mocks
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

export PATH="$TMP_DIR:$PATH"
export COMPRESS_LOG="$TMP_DIR/compress.log"

# Mock pg_dump
cat << 'EOF' > "$TMP_DIR/pg_dump"
#!/bin/bash
echo "mock db data"
EOF
chmod +x "$TMP_DIR/pg_dump"

# Mock aws
cat << 'EOF' > "$TMP_DIR/aws"
#!/bin/bash
cat > /dev/null
EOF
chmod +x "$TMP_DIR/aws"

# Mock gzip
cat << EOF > "$TMP_DIR/gzip"
#!/bin/bash
echo "gzip" > "\$COMPRESS_LOG"
cat
EOF
chmod +x "$TMP_DIR/gzip"

# Mock pigz
cat << EOF > "$TMP_DIR/pigz"
#!/bin/bash
echo "pigz" > "\$COMPRESS_LOG"
cat
EOF
chmod +x "$TMP_DIR/pigz"

# Run tests
echo "Testing with pigz available..."
export POSTGRES_USER=test
export POSTGRES_PASSWORD=test
export S3_BUCKET=test
export POSTGRES_DB=mydb

# Remove log
rm -f "$COMPRESS_LOG"
./backup.sh > "$TMP_DIR/backup.log" 2>&1 || {
    echo "backup.sh failed with pigz!"
    cat "$TMP_DIR/backup.log"
    exit 1
}

if ! grep -q "pigz" "$COMPRESS_LOG"; then
    echo "Error: pigz was not used when available."
    exit 1
fi
echo "Pass: pigz was used."

echo "Testing fallback to gzip..."
# Remove pigz mock
rm -f "$TMP_DIR/pigz"
rm -f "$COMPRESS_LOG"

./backup.sh > "$TMP_DIR/backup.log" 2>&1 || {
    echo "backup.sh failed with gzip!"
    cat "$TMP_DIR/backup.log"
    exit 1
}

if ! grep -q "gzip" "$COMPRESS_LOG"; then
    echo "Error: gzip was not used as a fallback."
    exit 1
fi
echo "Pass: gzip fallback worked."

echo "All tests passed."
exit 0
