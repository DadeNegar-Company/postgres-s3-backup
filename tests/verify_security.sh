#!/bin/bash
set -e

# setup
export PATH="$(pwd)/tests/mock_bin_sec:$PATH"
mkdir -p tests/mock_bin_sec

# cleanup on term
trap 'rm -rf tests/mock_bin_sec /tmp/verify_mock_*' 0

cat << 'MOCK' > tests/mock_bin_sec/psql
#!/bin/bash
echo "db1"
MOCK
chmod +x tests/mock_bin_sec/psql

cat << 'MOCK' > tests/mock_bin_sec/pg_dump
#!/bin/bash
echo "dumping db"
env > /tmp/verify_mock_pg_dump_env
MOCK
chmod +x tests/mock_bin_sec/pg_dump

cat << 'MOCK' > tests/mock_bin_sec/pigz
#!/bin/bash
cat
env > /tmp/verify_mock_pigz_env
MOCK
chmod +x tests/mock_bin_sec/pigz

cat << 'MOCK' > tests/mock_bin_sec/aws
#!/bin/bash
cat > /dev/null
env > /tmp/verify_mock_aws_env
MOCK
chmod +x tests/mock_bin_sec/aws

# Mock secret files
echo "secretpass" > /tmp/verify_mock_pgpass.txt
echo "secretawskey" > /tmp/verify_mock_awskey.txt
echo "secretawssecret" > /tmp/verify_mock_awssecret.txt

export POSTGRES_PASSWORD_FILE="/tmp/verify_mock_pgpass.txt"
export S3_ACCESS_KEY_ID_FILE="/tmp/verify_mock_awskey.txt"
export S3_SECRET_ACCESS_KEY_FILE="/tmp/verify_mock_awssecret.txt"
export POSTGRES_PASSWORD="secretpassold"
export AWS_ACCESS_KEY_ID="secretawskeyold"
export AWS_SECRET_ACCESS_KEY="secretawssecretold"
export S3_ACCESS_KEY_ID="s3awskey"
export S3_SECRET_ACCESS_KEY="s3awssecret"
export POSTGRES_USER="user"
export S3_BUCKET="bucket"
export BACKUP_ALL_DATABASES="true"
export AWS_SESSION_TOKEN="my_session_token"

# Execute
./backup.sh > /dev/null 2>&1

# Assertions
echo "Verifying pigz does not receive secrets..."
if grep -qE "POSTGRES_PASSWORD=|AWS_ACCESS_KEY_ID=|AWS_SECRET_ACCESS_KEY=|POSTGRES_PASSWORD_FILE=|S3_ACCESS_KEY_ID_FILE=|S3_SECRET_ACCESS_KEY_FILE=|S3_ACCESS_KEY_ID=|S3_SECRET_ACCESS_KEY=|AWS_SESSION_TOKEN=" /tmp/verify_mock_pigz_env; then
  echo "FAIL: Secrets leaked to pigz!"
  cat /tmp/verify_mock_pigz_env | grep -E "POSTGRES_PASSWORD=|AWS_ACCESS_KEY_ID=|AWS_SECRET_ACCESS_KEY=|POSTGRES_PASSWORD_FILE=|S3_ACCESS_KEY_ID_FILE=|S3_SECRET_ACCESS_KEY_FILE=|S3_ACCESS_KEY_ID=|S3_SECRET_ACCESS_KEY=|AWS_SESSION_TOKEN="
  kill -s TERM $$
fi
echo "SUCCESS: pigz did not receive secrets."

echo "Verifying pg_dump does not receive AWS secrets..."
if grep -qE "AWS_ACCESS_KEY_ID=|AWS_SECRET_ACCESS_KEY=" /tmp/verify_mock_pg_dump_env; then
  echo "FAIL: AWS secrets leaked to pg_dump!"
  cat /tmp/verify_mock_pg_dump_env | grep -E "AWS_ACCESS_KEY_ID=|AWS_SECRET_ACCESS_KEY="
  kill -s TERM $$
fi
echo "SUCCESS: pg_dump did not receive AWS secrets."

echo "Verifying pg_dump does receive PGPASSWORD..."
if ! grep -q "PGPASSWORD=" /tmp/verify_mock_pg_dump_env; then
  echo "FAIL: PGPASSWORD was not explicitly passed to pg_dump!"
  kill -s TERM $$
fi
echo "SUCCESS: pg_dump received PGPASSWORD explicitly."

echo "Verifying aws does receive AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY..."
if ! grep -q "AWS_ACCESS_KEY_ID=" /tmp/verify_mock_aws_env || ! grep -q "AWS_SECRET_ACCESS_KEY=" /tmp/verify_mock_aws_env; then
  echo "FAIL: AWS secrets were not explicitly passed to aws command!"
  kill -s TERM $$
fi
echo "SUCCESS: aws received AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY explicitly."

echo "Verifying aws receives AWS_SESSION_TOKEN without internal quotes..."
if ! grep -q "^AWS_SESSION_TOKEN=my_session_token$" /tmp/verify_mock_aws_env; then
  echo "FAIL: AWS_SESSION_TOKEN was not passed correctly (might have quotes or be missing)!"
  grep "AWS_SESSION_TOKEN" /tmp/verify_mock_aws_env || echo "Not found"
  kill -s TERM $$
fi
echo "SUCCESS: aws received AWS_SESSION_TOKEN explicitly and correctly."

echo "All security tests passed."
