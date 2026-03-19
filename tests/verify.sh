#!/bin/bash

set -e

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

export PATH="$TMP_DIR:$PATH"
export POSTGRES_USER="test_user"
export POSTGRES_PASSWORD="test_password"
export S3_BUCKET="test_bucket"
export POSTGRES_DB="test_db1,test_db2"

# Ensure mock executables write their invocation to a log file
export LOG_FILE="$TMP_DIR/mock.log"

cat << EOF > "$TMP_DIR/pg_dump"
#!/bin/bash
echo "pg_dump invoked with args: \$@" >> "\$LOG_FILE"
echo "mock pg_dump output"
EOF
chmod +x "$TMP_DIR/pg_dump"

cat << EOF > "$TMP_DIR/pigz"
#!/bin/bash
echo "pigz invoked" >> "\$LOG_FILE"
cat > /dev/null
EOF
chmod +x "$TMP_DIR/pigz"

cat << EOF > "$TMP_DIR/gzip"
#!/bin/bash
echo "gzip invoked" >> "\$LOG_FILE"
cat > /dev/null
EOF
chmod +x "$TMP_DIR/gzip"

cat << EOF > "$TMP_DIR/aws"
#!/bin/bash
echo "aws invoked with args: \$@" >> "\$LOG_FILE"
cat > /dev/null
EOF
chmod +x "$TMP_DIR/aws"

echo "Running backup.sh to verify pigz usage..."
./backup.sh > "$TMP_DIR/backup.log" 2>&1 || { echo "Backup failed!"; cat "$TMP_DIR/backup.log"; exit 1; }

echo "Checking log file for pigz invocation..."
if grep -q "pigz invoked" "$LOG_FILE"; then
  echo "SUCCESS: pigz was invoked as expected."
else
  echo "FAILURE: pigz was NOT invoked."
  echo "Log file contents:"
  cat "$LOG_FILE"
  echo "Backup script output:"
  cat "$TMP_DIR/backup.log"
  exit 1
fi

if grep -q "gzip invoked" "$LOG_FILE"; then
  echo "FAILURE: gzip was invoked when it shouldn't be."
  exit 1
fi

echo "All tests passed!"
