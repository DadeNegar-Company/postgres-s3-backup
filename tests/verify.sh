#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Setup temp directory for mocks
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

# Export required vars for backup.sh
export POSTGRES_USER="test_user"
export POSTGRES_PASSWORD="test_password"
export S3_BUCKET="test_bucket"
export POSTGRES_DB="test_db"

# Create mock executables
create_mock() {
  local cmd=$1
  local script=$2
  echo "#!/bin/bash" > "$MOCK_DIR/$cmd"
  echo "$script" >> "$MOCK_DIR/$cmd"
  chmod +x "$MOCK_DIR/$cmd"
}

# Test 1: pigz is available
echo "Running Test 1: pigz is available"
create_mock "pg_dump" "echo 'mock db dump'"
create_mock "aws" "cat > /dev/null; echo 'mock aws'"
create_mock "pigz" "cat > /dev/null; >&2 echo 'USED_PIGZ'"
create_mock "gzip" "cat > /dev/null; >&2 echo 'USED_GZIP'"
create_mock "psql" "echo 'test_db'"

# Create a test log file
TEST_LOG="$MOCK_DIR/test1.log"

# Run the backup script with the mock dir in PATH
PATH="$MOCK_DIR:$PATH" ../backup.sh > "$TEST_LOG" 2>&1 || true

if grep -q "Using pigz for parallel compression" "$TEST_LOG"; then
  echo -e "${GREEN}✓ Test 1 passed: pigz was selected${NC}"
else
  echo -e "${RED}✗ Test 1 failed: pigz was not selected${NC}"
  cat "$TEST_LOG"
  exit 1
fi

if grep -q "USED_PIGZ" "$TEST_LOG"; then
  echo -e "${GREEN}✓ Test 1 passed: pigz was used in pipeline${NC}"
else
  echo -e "${RED}✗ Test 1 failed: pigz was not used in pipeline${NC}"
  cat "$TEST_LOG"
  exit 1
fi

# Clean up pigz mock for Test 2
rm "$MOCK_DIR/pigz"

# Test 2: pigz is not available (fallback to gzip)
echo "Running Test 2: pigz is not available"
TEST_LOG2="$MOCK_DIR/test2.log"

# Run the backup script with the mock dir in PATH
PATH="$MOCK_DIR:$PATH" ../backup.sh > "$TEST_LOG2" 2>&1 || true

if grep -q "pigz not found, falling back to standard gzip" "$TEST_LOG2"; then
  echo -e "${GREEN}✓ Test 2 passed: gzip fallback was selected${NC}"
else
  echo -e "${RED}✗ Test 2 failed: gzip fallback was not selected${NC}"
  cat "$TEST_LOG2"
  exit 1
fi

if grep -q "USED_GZIP" "$TEST_LOG2"; then
  echo -e "${GREEN}✓ Test 2 passed: gzip was used in pipeline${NC}"
else
  echo -e "${RED}✗ Test 2 failed: gzip was not used in pipeline${NC}"
  cat "$TEST_LOG2"
  exit 1
fi

echo -e "${GREEN}All tests passed!${NC}"