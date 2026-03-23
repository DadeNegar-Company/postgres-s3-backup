#!/bin/bash

# Exit on explicitly thrown errors
set -e

# Mock directory and secret files
MOCK_DIR="$(pwd)/tests/mock_sec_dir"
mkdir -p "$MOCK_DIR"

echo "secret_db_pass" > "$MOCK_DIR/db_pass.txt"
echo "secret_aws_key" > "$MOCK_DIR/aws_key.txt"
echo "secret_aws_secret" > "$MOCK_DIR/aws_secret.txt"

# Cleanup trap
trap 'rm -rf "$MOCK_DIR" env_check.log' EXIT

export PATH="$MOCK_DIR:$PATH"

# Create mock for aws
cat << 'EOF' > "$MOCK_DIR/aws"
#!/bin/bash
cat > /dev/null
echo "AWS Mock executed with env:"
env | grep AWS_
EOF
chmod +x "$MOCK_DIR/aws"

# Create mock for pg_dump
cat << 'EOF' > "$MOCK_DIR/pg_dump"
#!/bin/bash
echo "pg_dump Mock executed" >&2
echo "Mock database content"
EOF
chmod +x "$MOCK_DIR/pg_dump"

# Create mock for pigz
cat << 'EOF' > "$MOCK_DIR/pigz"
#!/bin/bash
# We write env to a log to check if secrets leaked
env > "$(pwd)/env_check.log"
cat
EOF
chmod +x "$MOCK_DIR/pigz"

# Create mock for psql
cat << 'EOF' > "$MOCK_DIR/psql"
#!/bin/bash
echo "mock_db1"
EOF
chmod +x "$MOCK_DIR/psql"

echo "Running backup.sh to verify Docker Secrets and variable scoping..."

export POSTGRES_USER="testuser"
export S3_BUCKET="testbucket"
export BACKUP_ALL_DATABASES="true"

# Setup file inputs
export POSTGRES_PASSWORD_FILE="$MOCK_DIR/db_pass.txt"
export S3_ACCESS_KEY_ID_FILE="$MOCK_DIR/aws_key.txt"
export S3_SECRET_ACCESS_KEY_FILE="$MOCK_DIR/aws_secret.txt"

rm -f env_check.log
OUTPUT=$(./backup.sh 2>&1)

# Check if pigz (which doesn't need secrets) has them in its env
if grep -q "secret_db_pass" env_check.log || grep -q "secret_aws_key" env_check.log || grep -q "secret_aws_secret" env_check.log; then
  echo "FAILED: Secrets leaked into pigz's environment!"
  cat env_check.log
  exit 1
else
  echo "SUCCESS: Secrets did not leak into unrelated commands."
fi

# Ensure backup finished (which means it successfully read the files, otherwise it would exit early)
if echo "$OUTPUT" | grep -q "Backup process completed successfully."; then
  echo "SUCCESS: backup.sh executed successfully."
else
  echo "FAILED: backup.sh did not complete."
  echo "Output was:"
  echo "$OUTPUT"
  exit 1
fi
