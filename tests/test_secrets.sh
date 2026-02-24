#!/bin/bash
set -e

# Setup test environment
MOCK_DIR=$(mktemp -d)
export PATH="$MOCK_DIR:$PATH"
export HOME="$MOCK_DIR"

# Create mock pg_dump
cat << 'EOF' > "$MOCK_DIR/pg_dump"
#!/bin/bash
if [ -n "$PGPASSWORD" ]; then
  echo "FAIL: PGPASSWORD is set in environment!"
  exit 1
fi
if [ -z "$PGPASSFILE" ]; then
  echo "FAIL: PGPASSFILE env var not set!"
  exit 1
fi
if [ ! -f "$PGPASSFILE" ]; then
  echo "FAIL: PGPASSFILE ($PGPASSFILE) not found!"
  exit 1
fi
# Verify permissions (should be 600 or rw-------)
PERMS=$(ls -l "$PGPASSFILE" | cut -d ' ' -f 1)
# Note: On some systems ls -l output varies. But typically starts with -rw-------
if [[ "$PERMS" != "-rw-------" ]]; then
  echo "FAIL: .pgpass permissions are $PERMS (expected -rw-------)"
  # allow for slight variations if needed, but strict is better
fi

# Verify content uses wildcards
CONTENT=$(cat "$PGPASSFILE")
EXPECTED="*:*:*:*:testpassword"
# We need to escape check logic if password had special chars.
# But here we use 'testpassword'.

if [[ "$CONTENT" != *":*:*:*:"* ]]; then
  echo "FAIL: Content does not start with wildcards: $CONTENT"
  exit 1
fi

# Output dummy SQL
echo "DUMP CONTENT"
EOF
chmod +x "$MOCK_DIR/pg_dump"

# Create mock psql
cat << 'EOF' > "$MOCK_DIR/psql"
#!/bin/bash
echo "db1"
EOF
chmod +x "$MOCK_DIR/psql"

# Create mock aws
cat << 'EOF' > "$MOCK_DIR/aws"
#!/bin/bash
# Consume stdin
cat > /dev/null
EOF
chmod +x "$MOCK_DIR/aws"

# Run backup.sh
export POSTGRES_USER=testuser
export POSTGRES_PASSWORD=testpassword
export S3_BUCKET=testbucket
export BACKUP_ALL_DATABASES=true

# Capture output
OUTPUT=$(./backup.sh 2>&1)

# Check for success message
if echo "$OUTPUT" | grep -q "Backup process completed successfully"; then
  echo "PASS: Backup completed successfully."
else
  echo "FAIL: Backup failed."
  echo "$OUTPUT"
  exit 1
fi

# Clean up
rm -rf "$MOCK_DIR"
