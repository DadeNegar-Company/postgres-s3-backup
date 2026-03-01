#!/bin/bash

set -e

echo "Running security verification test..."

# Create a temporary directory for mocks
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

export PATH="$MOCK_DIR:$PATH"

# Create mock for psql
cat << 'EOF' > "$MOCK_DIR/psql"
#!/bin/bash
if [ -n "$PGPASSWORD" ]; then
    echo "SECURITY FAILURE: PGPASSWORD environment variable is set!" >&2
    exit 1
fi
if [ -z "$PGPASSFILE" ]; then
    echo "SECURITY FAILURE: PGPASSFILE environment variable is NOT set!" >&2
    exit 1
fi
if [ ! -f "$PGPASSFILE" ]; then
    echo "SECURITY FAILURE: PGPASSFILE $PGPASSFILE does not exist!" >&2
    exit 1
fi

# Assert file permissions
PERMS=$(stat -c "%a" "$PGPASSFILE")
if [ "$PERMS" != "600" ]; then
    echo "SECURITY FAILURE: PGPASSFILE permissions are $PERMS, expected 600!" >&2
    exit 1
fi

# Assert file contents using wildcards for host, port, db
EXPECTED="*:*:*:testuser:my\\\\tricky\\:pass\\:word"
ACTUAL=$(cat "$PGPASSFILE")
if [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "SECURITY FAILURE: PGPASSFILE contents are incorrect!" >&2
    echo "Expected: $EXPECTED" >&2
    echo "Actual:   $ACTUAL" >&2
    exit 1
fi

# Output expected databases
echo "db1"
echo "db2"
EOF
chmod +x "$MOCK_DIR/psql"

# Create mock for pg_dump
cat << 'EOF' > "$MOCK_DIR/pg_dump"
#!/bin/bash
if [ -n "$PGPASSWORD" ]; then
    echo "SECURITY FAILURE: PGPASSWORD environment variable is set!" >&2
    exit 1
fi
echo "Mock pg_dump data for database $6"
EOF
chmod +x "$MOCK_DIR/pg_dump"

# Create mock for gzip
cat << 'EOF' > "$MOCK_DIR/gzip"
#!/bin/bash
cat - | sed 's/Mock pg_dump data/GZIPPED Mock pg_dump data/'
EOF
chmod +x "$MOCK_DIR/gzip"

# Create mock for aws
cat << 'EOF' > "$MOCK_DIR/aws"
#!/bin/bash
echo "Uploading to $4"
cat -
EOF
chmod +x "$MOCK_DIR/aws"

# Run the backup script with tricky password
export POSTGRES_USER="testuser"
export POSTGRES_PASSWORD='my\tricky:pass:word'
export S3_BUCKET="my-test-bucket"
export S3_ACCESS_KEY_ID="xxx"
export S3_SECRET_ACCESS_KEY="yyy"
export BACKUP_ALL_DATABASES="true"

# Suppress backup.sh output to keep test output clean unless error occurs
if ! ./backup.sh > /dev/null; then
    echo "Test failed!"
    exit 1
fi

echo "All security checks passed!"
