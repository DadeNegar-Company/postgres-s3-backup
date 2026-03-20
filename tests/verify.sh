#!/bin/bash
set -e

# Setup temp directory for mocks
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Export needed vars
export POSTGRES_USER="testuser"
export POSTGRES_PASSWORD="testpassword"
export S3_BUCKET="testbucket"
export POSTGRES_DB="testdb"
export DATE=$(date +"%Y-%m-%dT%H:%M:%SZ")

# Create a mock aws that consumes stdin to prevent SIGPIPE
cat << 'MOCK' > "$TMP_DIR/aws"
#!/bin/bash
cat > /dev/null
echo "mock aws executed"
MOCK
chmod +x "$TMP_DIR/aws"

# Create a mock pg_dump
cat << 'MOCK' > "$TMP_DIR/pg_dump"
#!/bin/bash
echo "dummy pg_dump output"
MOCK
chmod +x "$TMP_DIR/pg_dump"

# Test 1: with pigz in PATH
echo "--- Testing with pigz ---"
mkdir -p "$TMP_DIR/bin1"
cp "$TMP_DIR/aws" "$TMP_DIR/bin1/aws"
cp "$TMP_DIR/pg_dump" "$TMP_DIR/bin1/pg_dump"

cat << 'MOCK' > "$TMP_DIR/bin1/pigz"
#!/bin/bash
cat > /dev/null
echo "mock pigz executed"
MOCK
chmod +x "$TMP_DIR/bin1/pigz"

# Run backup.sh with pigz in PATH
OUTPUT_PIGZ=$(PATH="$TMP_DIR/bin1:$PATH" bash ./backup.sh 2>&1)
if echo "$OUTPUT_PIGZ" | grep -q "Using pigz for parallel compression"; then
    echo "SUCCESS: Found pigz message."
else
    echo "FAILED: Did not find pigz message."
    echo "$OUTPUT_PIGZ"
    exit 1
fi

# Test 2: WITHOUT pigz in PATH
echo "--- Testing without pigz ---"

# Set up a restricted path with only necessary commands, excluding pigz
mkdir -p "$TMP_DIR/bin_strict"
for cmd in bash date echo sed grep psql cat awk tr rm mktemp command dirname basename; do
    P=$(command -v $cmd 2>/dev/null || true)
    if [ -n "$P" ]; then
        ln -s "$P" "$TMP_DIR/bin_strict/$cmd" 2>/dev/null || cp "$P" "$TMP_DIR/bin_strict/$cmd"
    fi
done

# Copy mocks into strict path
cp "$TMP_DIR/aws" "$TMP_DIR/bin_strict/aws"
cp "$TMP_DIR/pg_dump" "$TMP_DIR/bin_strict/pg_dump"

cat << 'MOCK' > "$TMP_DIR/bin_strict/gzip"
#!/bin/bash
cat > /dev/null
echo "mock gzip executed"
MOCK
chmod +x "$TMP_DIR/bin_strict/gzip"

OUTPUT_GZIP=$(PATH="$TMP_DIR/bin_strict" bash ./backup.sh 2>&1 || true)
if echo "$OUTPUT_GZIP" | grep -q "pigz not found, falling back to gzip"; then
    echo "SUCCESS: Found gzip fallback message."
else
    echo "FAILED: Did not find gzip fallback message."
    echo "$OUTPUT_GZIP"
    exit 1
fi

echo "ALL TESTS PASSED"
