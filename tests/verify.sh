#!/bin/bash

# Exit on explicitly thrown errors
set -e

# Mock directory
MOCK_DIR="$(pwd)/tests/mock_dir"
mkdir -p "$MOCK_DIR"
trap 'rm -rf "$MOCK_DIR" pigz_called.log' EXIT

export PATH="$MOCK_DIR:$PATH"

# Create mock for aws
cat << 'EOF' > "$MOCK_DIR/aws"
#!/bin/bash
cat > /dev/null
echo "AWS Mock executed with args: $@"
EOF
chmod +x "$MOCK_DIR/aws"

# Create mock for pg_dump
cat << 'EOF' > "$MOCK_DIR/pg_dump"
#!/bin/bash
echo "pg_dump Mock executed with args: $@" >&2
echo "Mock database content"
EOF
chmod +x "$MOCK_DIR/pg_dump"

# Create mock for pigz
cat << 'EOF' > "$MOCK_DIR/pigz"
#!/bin/bash
echo "pigz Mock executed" >> "$(pwd)/pigz_called.log"
cat
EOF
chmod +x "$MOCK_DIR/pigz"

# Create mock for psql
cat << 'EOF' > "$MOCK_DIR/psql"
#!/bin/bash
echo "mock_db1"
echo "mock_db2"
EOF
chmod +x "$MOCK_DIR/psql"

echo "Running backup.sh to ensure pigz is chosen..."

export POSTGRES_USER="testuser"
export POSTGRES_PASSWORD="testpassword"
export S3_BUCKET="testbucket"
export BACKUP_ALL_DATABASES="true"

rm -f pigz_called.log
OUTPUT=$(./backup.sh 2>&1)

if grep -q "pigz Mock executed" pigz_called.log; then
  echo "SUCCESS: pigz was executed!"
else
  echo "FAILED: pigz was not executed."
  echo "Output was:"
  echo "$OUTPUT"
  exit 1
fi
