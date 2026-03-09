#!/bin/bash
# Exit on error
set -e

# Mock environment
MOCK_DIR=$(mktemp -d)
export PATH="$MOCK_DIR:$PATH"

# Mock psql, pg_dump, aws, gzip
cat << 'EOF' > "$MOCK_DIR/psql"
#!/bin/bash
exit 0
EOF

cat << 'EOF' > "$MOCK_DIR/pg_dump"
#!/bin/bash
exit 0
EOF

cat << 'EOF' > "$MOCK_DIR/aws"
#!/bin/bash
exit 0
EOF

cat << 'EOF' > "$MOCK_DIR/gzip"
#!/bin/bash
exit 0
EOF

chmod +x "$MOCK_DIR"/*

echo "Testing Docker Secrets implementation..."

# Test 1: Load secret from file successfully
export POSTGRES_USER_FILE="$MOCK_DIR/pg_user"
echo "secret_user" > "$POSTGRES_USER_FILE"

export POSTGRES_PASSWORD_FILE="$MOCK_DIR/pg_pass"
echo "secret_pass" > "$POSTGRES_PASSWORD_FILE"

export S3_BUCKET="my-bucket"

# Run backup.sh and suppress output.
# Need to use 'true' to avoid bash stopping because of set -e inside the script.
# We modify backup.sh in-memory to not actually run the loops for testing variables.
# Actually, since it requires POSTGRES_DB or BACKUP_ALL_DATABASES, we can just run it.
export POSTGRES_DB="mydb"

output=$(bash ./backup.sh 2>&1) || true

# Check if the variables were loaded correctly.
# The script will echo "Starting backup process at..."
# We can't directly inspect variables after it exits.
# Let's write a small wrapper to source backup.sh and override `exit`.

cat << 'EOF' > "$MOCK_DIR/wrapper.sh"
#!/bin/bash
# Source the file, override exit
exit() {
  return $1 2>/dev/null || true
}
source ./backup.sh
echo "TEST_PG_USER=$POSTGRES_USER"
echo "TEST_PG_PASS=$POSTGRES_PASSWORD"
EOF

# Unset plain variables just in case
unset POSTGRES_USER POSTGRES_PASSWORD

# Run wrapper
wrapper_out=$(bash "$MOCK_DIR/wrapper.sh")

if echo "$wrapper_out" | grep -q "TEST_PG_USER=secret_user" && echo "$wrapper_out" | grep -q "TEST_PG_PASS=secret_pass"; then
  echo "✅ Test 1 Passed: Secrets loaded correctly from files."
else
  echo "❌ Test 1 Failed: Secrets not loaded."
  echo "Output: $wrapper_out"
  exit 1
fi

# Test 2: Mutually exclusive failure
export POSTGRES_USER="plain_user"
wrapper_out_fail=$(bash "$MOCK_DIR/wrapper.sh" 2>&1) || true
if echo "$wrapper_out_fail" | grep -q "mutually exclusive"; then
  echo "✅ Test 2 Passed: Mutually exclusive check works."
else
  echo "❌ Test 2 Failed: Mutually exclusive check bypassed."
  echo "Output: $wrapper_out_fail"
  exit 1
fi

unset POSTGRES_USER

# Test 3: Missing file failure
export POSTGRES_USER_FILE="$MOCK_DIR/non_existent_file"
wrapper_out_missing=$(bash "$MOCK_DIR/wrapper.sh" 2>&1) || true
if echo "$wrapper_out_missing" | grep -q "file does not exist"; then
  echo "✅ Test 3 Passed: Missing file check works."
else
  echo "❌ Test 3 Failed: Missing file check bypassed."
  echo "Output: $wrapper_out_missing"
  exit 1
fi

# Cleanup
rm -rf "$MOCK_DIR"
echo "All tests passed successfully."
