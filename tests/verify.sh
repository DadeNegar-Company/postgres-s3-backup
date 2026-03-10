#!/bin/bash

set -e

# Create a temporary directory for tests
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Mock external binaries
mkdir -p "$TEST_DIR/bin"
cat << 'EOF' > "$TEST_DIR/bin/pg_dump"
#!/bin/bash
echo "mock_pg_dump"
EOF

cat << 'EOF' > "$TEST_DIR/bin/gzip"
#!/bin/bash
cat
EOF

cat << 'EOF' > "$TEST_DIR/bin/aws"
#!/bin/bash
echo "mock_aws $@"
EOF

cat << 'EOF' > "$TEST_DIR/bin/psql"
#!/bin/bash
echo "mock_psql"
EOF

chmod +x "$TEST_DIR/bin/"*

export PATH="$TEST_DIR/bin:$PATH"

# Create mock secret files
echo -n "testuser" > "$TEST_DIR/pg_user"
echo -n "testpass" > "$TEST_DIR/pg_pass"
echo -n "testbucket" > "$TEST_DIR/s3_bucket"

# Set _FILE environment variables
export POSTGRES_USER_FILE="$TEST_DIR/pg_user"
export POSTGRES_PASSWORD_FILE="$TEST_DIR/pg_pass"
export S3_BUCKET_FILE="$TEST_DIR/s3_bucket"
export POSTGRES_DB="testdb"

# Execute backup.sh and capture output
OUTPUT=$(./backup.sh)

# Assert secrets were loaded successfully and not throwing errors
if [[ "$OUTPUT" == *"Backup process completed successfully."* ]]; then
    echo "Test passed: Secrets loaded correctly via _FILE variables."
else
    echo "Test failed: Expected success message."
    echo "Output was:"
    echo "$OUTPUT"
    exit 1
fi
