#!/bin/bash
set -e

echo "Running security verification..."

TMP_DIR=$(mktemp -d)
SECRET_DIR=$(mktemp -d)

# Cleanup temporary mock and secret directories on exit to prevent environment pollution
trap 'rm -rf "$TMP_DIR" "$SECRET_DIR"' EXIT

export PATH="$TMP_DIR:$PATH"

cat << 'MOCK' > "$TMP_DIR/pg_dump"
#!/bin/bash
if [ "$6" != "secret_user" ]; then
    echo "Error: pg_dump Expected POSTGRES_USER to be secret_user, got $6 (called with $@)" >&2
    return 1 2>/dev/null || true
fi
echo "mock pg_dump data"
# Sleep briefly so pipe doesn't break instantly
sleep 1
MOCK
chmod +x "$TMP_DIR/pg_dump"

cat << 'MOCK' > "$TMP_DIR/aws"
#!/bin/bash
if [ "$AWS_ACCESS_KEY_ID" != "secret_s3_key" ] || [ "$AWS_SECRET_ACCESS_KEY" != "secret_s3_secret" ]; then
    echo "Error: aws keys not set correctly in env. Got $AWS_ACCESS_KEY_ID / $AWS_SECRET_ACCESS_KEY" >&2
    return 1 2>/dev/null || true
fi
# consume stdin to avoid SIGPIPE in pg_dump
cat > /dev/null
MOCK
chmod +x "$TMP_DIR/aws"

cat << 'MOCK' > "$TMP_DIR/gzip"
#!/bin/bash
cat
MOCK
chmod +x "$TMP_DIR/gzip"

cat << 'MOCK' > "$TMP_DIR/psql"
#!/bin/bash
echo "mockdb1"
echo "mockdb2"
MOCK
chmod +x "$TMP_DIR/psql"

echo "secret_user" > "$SECRET_DIR/user.txt"
echo "secret_pass" > "$SECRET_DIR/pass.txt"
echo "secret_s3_key" > "$SECRET_DIR/s3_key.txt"
echo "secret_s3_secret" > "$SECRET_DIR/s3_secret.txt"

export POSTGRES_USER_FILE="$SECRET_DIR/user.txt"
export POSTGRES_PASSWORD_FILE="$SECRET_DIR/pass.txt"
export S3_BUCKET="mybucket"
export S3_ACCESS_KEY_ID_FILE="$SECRET_DIR/s3_key.txt"
export S3_SECRET_ACCESS_KEY_FILE="$SECRET_DIR/s3_secret.txt"
export POSTGRES_DB="testdb"

unset POSTGRES_USER
unset POSTGRES_PASSWORD
unset S3_ACCESS_KEY_ID
unset S3_SECRET_ACCESS_KEY

# run backup script in a subshell, or let it fail without returning 1
set +e
bash ./backup.sh
RC=$?
set -e
if [ $RC -eq 0 ]; then
  echo "Success! Script ran using docker secrets."
else
  echo "Failed with return code $RC!"
fi
