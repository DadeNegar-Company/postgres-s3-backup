#!/bin/bash

set -e

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

export PATH="$TMP_DIR:$PATH"

# Create mock executables
cat << 'EOF' > "$TMP_DIR/pg_dump"
#!/bin/bash
echo "mock pg_dump data"
EOF
chmod +x "$TMP_DIR/pg_dump"

cat << 'EOF' > "$TMP_DIR/psql"
#!/bin/bash
echo "db1"
echo "db2"
EOF
chmod +x "$TMP_DIR/psql"

cat << 'EOF' > "$TMP_DIR/gzip"
#!/bin/bash
cat
EOF
chmod +x "$TMP_DIR/gzip"

cat << 'EOF' > "$TMP_DIR/aws"
#!/bin/bash
cat > /dev/null
echo "mock aws called"
EOF
chmod +x "$TMP_DIR/aws"

# Create secret files
echo "secret_user" > "$TMP_DIR/user.txt"
echo "secret_pass" > "$TMP_DIR/pass.txt"
echo "my_bucket" > "$TMP_DIR/bucket.txt"
echo "db1,db2" > "$TMP_DIR/dbs.txt"

# Export file variables
export POSTGRES_USER_FILE="$TMP_DIR/user.txt"
export POSTGRES_PASSWORD_FILE="$TMP_DIR/pass.txt"
export S3_BUCKET_FILE="$TMP_DIR/bucket.txt"
export POSTGRES_DB_FILE="$TMP_DIR/dbs.txt"

# Test variables unset
unset POSTGRES_USER
unset POSTGRES_PASSWORD
unset S3_BUCKET
unset POSTGRES_DB

# Run the backup script
bash ./backup.sh > "$TMP_DIR/output.log" 2>&1 || {
  echo "Backup script failed:"
  cat "$TMP_DIR/output.log"
  exit 1
}

if grep -q "Streaming backup of database: db1" "$TMP_DIR/output.log"; then
  echo "Success: Mock secrets successfully loaded and backup ran."
else
  echo "Failure: Expected output missing."
  cat "$TMP_DIR/output.log"
  exit 1
fi
