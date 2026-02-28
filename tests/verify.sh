#!/bin/bash

set -e

# Create a temporary directory for mocks
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

export PATH="$MOCK_DIR:$PATH"

# Create mock for aws
cat << 'EOF' > "$MOCK_DIR/aws"
#!/bin/bash
echo "Mock aws called with: $@"
# Assert that PGPASSWORD is not exported
if [ -n "$PGPASSWORD" ]; then
    echo "ERROR: PGPASSWORD is set in environment!"
    exit 1
fi
# Assert that PGPASSFILE is exported
if [ -z "$PGPASSFILE" ]; then
    echo "ERROR: PGPASSFILE is not set in environment!"
    exit 1
fi
# Read and print the passfile contents to verify format
echo "Contents of PGPASSFILE ($PGPASSFILE):"
cat "$PGPASSFILE"
EOF
chmod +x "$MOCK_DIR/aws"

# Create mock for pg_dump
cat << 'EOF' > "$MOCK_DIR/pg_dump"
#!/bin/bash
echo "Mock pg_dump called with: $@"
# Output dummy data
echo "dummy backup data"
EOF
chmod +x "$MOCK_DIR/pg_dump"

# Create mock for psql
cat << 'EOF' > "$MOCK_DIR/psql"
#!/bin/bash
echo "Mock psql called with: $@"
echo "db1"
echo "db2"
EOF
chmod +x "$MOCK_DIR/psql"


# Set required environment variables
export POSTGRES_HOST="db.example.com"
export POSTGRES_PORT="5432"
export POSTGRES_USER="admin"
export POSTGRES_PASSWORD="secret\\pass:word"
export S3_BUCKET="my-backups"
export S3_ACCESS_KEY_ID="XXX"
export S3_SECRET_ACCESS_KEY="YYY"
export POSTGRES_DB="testdb"

echo "Running backup.sh..."
./backup.sh > backup_output.log 2>&1

echo "Backup script finished. Checking results..."
cat backup_output.log

# Verify that the pgpassfile contents are correct
if grep -q 'db.example.com:5432:\*:admin:secret\\\\pass\\:word' backup_output.log; then
    echo "SUCCESS: PGPASSFILE has correct format and escaping."
else
    echo "ERROR: PGPASSFILE does not have correct format/escaping!"
    exit 1
fi

if grep -q 'ERROR: PGPASSWORD is set in environment!' backup_output.log; then
    echo "ERROR: PGPASSWORD was leaked!"
    exit 1
fi

if grep -q 'ERROR: PGPASSFILE is not set in environment!' backup_output.log; then
    echo "ERROR: PGPASSFILE was not set!"
    exit 1
fi

echo "All tests passed successfully!"
