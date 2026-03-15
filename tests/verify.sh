#!/bin/bash

set -e

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

export PATH="$TMP_DIR:$PATH"

# Create mocks
cat << 'EOF' > "$TMP_DIR/pg_dump"
#!/bin/bash
echo "mock pg_dump data"
EOF
chmod +x "$TMP_DIR/pg_dump"

cat << 'EOF' > "$TMP_DIR/aws"
#!/bin/bash
# Consume stdin to prevent SIGPIPE in upstream
cat > /dev/null
echo "mock aws called"
EOF
chmod +x "$TMP_DIR/aws"

# Mock pigz to record it was called
cat << EOF > "$TMP_DIR/pigz"
#!/bin/bash
# Consume stdin to prevent SIGPIPE
cat > /dev/null
echo "PIGZ_WAS_CALLED" > "$TMP_DIR/pigz_called"
EOF
chmod +x "$TMP_DIR/pigz"

export POSTGRES_USER="test_user"
export POSTGRES_PASSWORD="test_password"
export S3_BUCKET="test_bucket"
export POSTGRES_DB="test_db"
export S3_ACCESS_KEY_ID="test_key"
export S3_SECRET_ACCESS_KEY="test_secret"

# Run backup script and capture output
output=$(./backup.sh 2>&1)

if [ ! -f "$TMP_DIR/pigz_called" ]; then
    echo "Test failed: pigz was not called"
    echo "Output:"
    echo "$output"
    exit 1
fi

echo "Test passed: pigz was called successfully"
