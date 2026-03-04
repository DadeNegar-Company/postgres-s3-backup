#!/bin/bash
set -e

# Secure default umask
umask 0077

echo "Running security verification for backup.sh..."

# Create a mock directory for our binaries
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT
export PATH="$MOCK_DIR:$PATH"

# Create a mock for pg_dump to assert PGPASSFILE and no PGPASSWORD
cat << 'EOF' > "$MOCK_DIR/pg_dump"
#!/bin/bash
if [ -n "$PGPASSWORD" ]; then
    echo "❌ SECURITY FAILURE: PGPASSWORD is set!" >&2
    exit 1
fi
if [ -z "$PGPASSFILE" ]; then
    echo "❌ SECURITY FAILURE: PGPASSFILE is not set!" >&2
    exit 1
fi
if [ ! -f "$PGPASSFILE" ]; then
    echo "❌ SECURITY FAILURE: PGPASSFILE does not exist: $PGPASSFILE" >&2
    exit 1
fi

# Check permissions of PGPASSFILE (should be 600 or stricter)
PERMS=$(stat -c "%a" "$PGPASSFILE")
if [ "$PERMS" != "600" ]; then
    echo "❌ SECURITY FAILURE: PGPASSFILE permissions are not 0600 (actual: $PERMS)" >&2
    exit 1
fi

# Check contents of PGPASSFILE
CONTENT=$(cat "$PGPASSFILE")
EXPECTED='*:*:*:testuser:test\:pass\\word'
if [ "$CONTENT" != "$EXPECTED" ]; then
    echo "❌ SECURITY FAILURE: PGPASSFILE contents mismatch." >&2
    echo "Expected: $EXPECTED" >&2
    echo "Actual:   $CONTENT" >&2
    exit 1
fi

# Output dummy data to simulate pg_dump
echo "dummy db dump data"
EOF
chmod +x "$MOCK_DIR/pg_dump"

# Create a mock for sed to avoid interfering with backup logic
cat << 'EOF' > "$MOCK_DIR/aws"
#!/bin/bash
cat - > /dev/null
EOF
chmod +x "$MOCK_DIR/aws"

# Create a mock for psql
cat << 'EOF' > "$MOCK_DIR/psql"
#!/bin/bash
if [ -n "$PGPASSWORD" ]; then
    echo "❌ SECURITY FAILURE: PGPASSWORD is set in psql!" >&2
    exit 1
fi
if [ -z "$PGPASSFILE" ]; then
    echo "❌ SECURITY FAILURE: PGPASSFILE is not set in psql!" >&2
    exit 1
fi
echo "test_db"
EOF
chmod +x "$MOCK_DIR/psql"


# Create a mock for gzip
cat << 'EOF' > "$MOCK_DIR/gzip"
#!/bin/bash
cat -
EOF
chmod +x "$MOCK_DIR/gzip"

# Set up required environment variables for backup.sh
export POSTGRES_USER="testuser"
export POSTGRES_PASSWORD='test:pass\word'
export S3_BUCKET="test-bucket"
export S3_ACCESS_KEY_ID="test-key"
export S3_SECRET_ACCESS_KEY="test-secret"
export BACKUP_ALL_DATABASES="true"

# Run the backup script
bash ./backup.sh || exit 1

echo "✅ All security checks passed."
