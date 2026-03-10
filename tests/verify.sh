#!/bin/bash

# Exit on explicitly thrown errors
set -e
set -o pipefail

export PATH="$(pwd)/tests/mocks:$PATH"

mkdir -p tests/mocks
cat << 'MOCK_EOF' > tests/mocks/pg_dump
#!/bin/bash
echo "mock_pg_dump"
MOCK_EOF
chmod +x tests/mocks/pg_dump

cat << 'MOCK_EOF' > tests/mocks/aws
#!/bin/bash
echo "mock_aws"
MOCK_EOF
chmod +x tests/mocks/aws

cat << 'MOCK_EOF' > tests/mocks/gzip
#!/bin/bash
echo "mock_gzip"
cat > /dev/null
MOCK_EOF
chmod +x tests/mocks/gzip

export POSTGRES_USER="test_user"
export POSTGRES_PASSWORD="test_password"
export S3_BUCKET="test_bucket"
export POSTGRES_DB="test_db"
export AWS_ACCESS_KEY_ID="test_key"
export AWS_SECRET_ACCESS_KEY="test_secret"

# Test 1: Fallback to gzip
echo "Running Test 1: Fallback to gzip (pigz unavailable)"
rm -f tests/mocks/pigz
./backup.sh

# Test 2: Use pigz
echo "Running Test 2: Use pigz (pigz available)"
cat << 'MOCK_EOF' > tests/mocks/pigz
#!/bin/bash
echo "mock_pigz"
cat > /dev/null
MOCK_EOF
chmod +x tests/mocks/pigz
./backup.sh

echo "All tests passed successfully!"
