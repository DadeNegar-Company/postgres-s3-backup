#!/bin/bash
set -e

# Setup mock directory
MOCK_DIR=$(mktemp -d)

# Mock pg_dump
cat << 'MOCK_SCRIPT' > "$MOCK_DIR/pg_dump"
#!/bin/bash
echo "mock_pg_dump"
MOCK_SCRIPT
chmod +x "$MOCK_DIR/pg_dump"

# Mock aws
cat << 'MOCK_SCRIPT' > "$MOCK_DIR/aws"
#!/bin/bash
# Read input and check for "mock_pigz" to verify pigz was used
input=$(cat)
if [[ "$input" == *"mock_pigz"* ]]; then
  echo "aws received mock_pigz output successfully"
else
  echo "Error: aws did not receive mock_pigz output" >&2
  echo "Actual input: $input" >&2
  exit 1
fi
MOCK_SCRIPT
chmod +x "$MOCK_DIR/aws"

# Mock pigz
cat << 'MOCK_SCRIPT' > "$MOCK_DIR/pigz"
#!/bin/bash
# Just append mock_pigz to verify it ran
cat
echo " mock_pigz "
MOCK_SCRIPT
chmod +x "$MOCK_DIR/pigz"

# Run in subshell to isolate PATH changes
(
  export PATH="$MOCK_DIR:$PATH"

  # Test variables
  export POSTGRES_USER="test_user"
  export POSTGRES_PASSWORD="test_password"
  export S3_BUCKET="test_bucket"
  export POSTGRES_DB="test_db"
  export S3_ACCESS_KEY_ID="test_key"
  export S3_SECRET_ACCESS_KEY="test_secret"

  echo "Running backup.sh with pigz mock..."
  if ./backup.sh; then
    echo "SUCCESS: backup.sh executed successfully with pigz."
  else
    echo "FAILURE: backup.sh execution failed."
    exit 1
  fi
)
TEST_STATUS=$?

rm -rf "$MOCK_DIR"

if [ $TEST_STATUS -ne 0 ]; then
  echo "Test failed!"
  exit 1
fi
