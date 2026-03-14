#!/bin/bash
set -e

# Create a temporary directory for mocks and test files
TMP_DIR=$(mktemp -d)

# Ensure cleanup on exit
trap 'rm -rf "$TMP_DIR"' EXIT

# Set up mock credential files
echo "mock_user" > "$TMP_DIR/user.txt"
echo "mock_pass" > "$TMP_DIR/pass.txt"
echo "mock_s3_key" > "$TMP_DIR/s3_key.txt"
echo "mock_s3_secret" > "$TMP_DIR/s3_secret.txt"
echo "mock_aws_key" > "$TMP_DIR/aws_key.txt"
echo "mock_aws_secret" > "$TMP_DIR/aws_secret.txt"

# Export test variables
export POSTGRES_USER_FILE="$TMP_DIR/user.txt"
export POSTGRES_PASSWORD_FILE="$TMP_DIR/pass.txt"
export S3_ACCESS_KEY_ID_FILE="$TMP_DIR/s3_key.txt"
export S3_SECRET_ACCESS_KEY_FILE="$TMP_DIR/s3_secret.txt"
export AWS_ACCESS_KEY_ID_FILE="$TMP_DIR/aws_key.txt"
export AWS_SECRET_ACCESS_KEY_FILE="$TMP_DIR/aws_secret.txt"

export POSTGRES_DB="test"
export S3_BUCKET="test_bucket"

# Create mock executables directory
mkdir -p "$TMP_DIR/bin"
export PATH="$TMP_DIR/bin:$PATH"

# Create mock for pg_dump
cat << 'EOF' > "$TMP_DIR/bin/pg_dump"
#!/bin/bash
echo "pg_dump output"
EOF
chmod +x "$TMP_DIR/bin/pg_dump"

# Create mock for gzip
cat << 'EOF' > "$TMP_DIR/bin/gzip"
#!/bin/bash
cat
EOF
chmod +x "$TMP_DIR/bin/gzip"

# Create mock for aws
cat << 'EOF' > "$TMP_DIR/bin/aws"
#!/bin/bash
cat > /dev/null
echo "aws called"
EOF
chmod +x "$TMP_DIR/bin/aws"

# Create mock for psql
cat << 'EOF' > "$TMP_DIR/bin/psql"
#!/bin/bash
echo "test"
EOF
chmod +x "$TMP_DIR/bin/psql"


# Execute the backup script and capture output
echo "Running backup.sh..."
if ! ./backup.sh > "$TMP_DIR/output.log" 2>&1; then
    echo "Test failed! backup.sh exited with error."
    cat "$TMP_DIR/output.log"
    exit 1
fi

echo "Test output:"
cat "$TMP_DIR/output.log"

if grep -q "Backup process completed successfully." "$TMP_DIR/output.log"; then
    echo "Test passed: Backup completed successfully using _FILE credentials."
    exit 0
else
    echo "Test failed: Success message not found."
    exit 1
fi
