#!/bin/bash
set -e
set -o pipefail
set -u

# Test docker secret support in backup.sh
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "mockuser" > "$TMP_DIR/user.txt"
echo "mockpass" > "$TMP_DIR/pass.txt"
echo "mockbucket" > "$TMP_DIR/bucket.txt"
echo "mockaccesskey" > "$TMP_DIR/accesskey.txt"
echo "mocksecretkey" > "$TMP_DIR/secretkey.txt"

export POSTGRES_USER_FILE="$TMP_DIR/user.txt"
export POSTGRES_PASSWORD_FILE="$TMP_DIR/pass.txt"
export S3_BUCKET_FILE="$TMP_DIR/bucket.txt"
export S3_ACCESS_KEY_ID_FILE="$TMP_DIR/accesskey.txt"
export S3_SECRET_ACCESS_KEY_FILE="$TMP_DIR/secretkey.txt"

# Add mock commands
mkdir -p "$TMP_DIR/bin"
cat << 'MOCK' > "$TMP_DIR/bin/pg_dump"
#!/bin/sh
echo "mock pg_dump"
MOCK
chmod +x "$TMP_DIR/bin/pg_dump"

cat << 'MOCK' > "$TMP_DIR/bin/gzip"
#!/bin/sh
cat -
MOCK
chmod +x "$TMP_DIR/bin/gzip"

cat << 'MOCK' > "$TMP_DIR/bin/aws"
#!/bin/sh
cat > /dev/null
echo "mock aws args: \$@"
MOCK
chmod +x "$TMP_DIR/bin/aws"

cat << 'MOCK' > "$TMP_DIR/bin/psql"
#!/bin/sh
echo "testdb"
MOCK
chmod +x "$TMP_DIR/bin/psql"

export PATH="$TMP_DIR/bin:$PATH"

export POSTGRES_DB="testdb"

echo "Running backup.sh to verify secret loading..."
./backup.sh > "$TMP_DIR/output.log" 2>&1

cat "$TMP_DIR/output.log"

if grep -q "Error: POSTGRES_USER must be provided." "$TMP_DIR/output.log"; then
    echo "Test failed: Secret loading did not work correctly."
    kill -ABRT $$
fi

echo "Test passed: Secrets loaded successfully via files."
