#!/bin/bash

# Exit on explicitly thrown errors
set -e
set -o pipefail

# Secure default umask to ensure created files are only readable by the owner
umask 0077

# Default variables
DATE=$(date +"%Y-%m-%dT%H:%M:%SZ")
S3_PREFIX=${S3_PREFIX:-""}
POSTGRES_HOST=${POSTGRES_HOST:-"localhost"}
POSTGRES_PORT=${POSTGRES_PORT:-"5432"}

if [ -z "$POSTGRES_USER" ]; then
  echo "Error: POSTGRES_USER must be provided."
  exit 1
fi

if [[ -v POSTGRES_PASSWORD_FILE && -f "$POSTGRES_PASSWORD_FILE" ]]; then
  POSTGRES_PASSWORD=$(head -n 1 "$POSTGRES_PASSWORD_FILE" | tr -d '\r\n')
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
  echo "Error: POSTGRES_PASSWORD or POSTGRES_PASSWORD_FILE must be provided."
  exit 1
fi

if [ -z "$S3_BUCKET" ]; then
  echo "Error: S3_BUCKET must be provided."
  exit 1
fi

echo "Starting backup process at $DATE"

# Configure AWS CLI using standard environment variables if custom ones were provided
if [[ -v S3_ACCESS_KEY_ID_FILE && -f "$S3_ACCESS_KEY_ID_FILE" ]]; then
  AWS_ACCESS_KEY_ID=$(head -n 1 "$S3_ACCESS_KEY_ID_FILE" | tr -d '\r\n')
else
  AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY_ID:-$AWS_ACCESS_KEY_ID}
fi

if [[ -v S3_SECRET_ACCESS_KEY_FILE && -f "$S3_SECRET_ACCESS_KEY_FILE" ]]; then
  AWS_SECRET_ACCESS_KEY=$(head -n 1 "$S3_SECRET_ACCESS_KEY_FILE" | tr -d '\r\n')
else
  AWS_SECRET_ACCESS_KEY=${S3_SECRET_ACCESS_KEY:-$AWS_SECRET_ACCESS_KEY}
fi

export AWS_DEFAULT_REGION=${S3_REGION:-us-east-1}

# Security: Unexport secrets so they don't leak into child processes (like pigz) that don't need them.
# The secrets are still available as local variables and will be explicitly passed to pg_dump and aws.
export -n POSTGRES_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY POSTGRES_PASSWORD_FILE S3_ACCESS_KEY_ID_FILE S3_SECRET_ACCESS_KEY_FILE S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY

# If BACKUP_ALL_DATABASES is set to true, fetch all databases dynamically
if [ "$BACKUP_ALL_DATABASES" = "true" ] || [ "$BACKUP_ALL_DATABASES" = "1" ]; then
  echo "BACKUP_ALL_DATABASES is set. Fetching all databases from the server..."
  DBS_LIST=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;")
  # Convert the newline separated list into an array
  mapfile -t DBS <<< "$DBS_LIST"
elif [ -n "$POSTGRES_DB" ]; then
  IFS=',' read -ra DBS <<< "$POSTGRES_DB"
else
  echo "Neither POSTGRES_DB nor BACKUP_ALL_DATABASES is provided. Nothing to backup."
  exit 0
fi

# Optimization: Pre-calculate static S3 destination and AWS arguments outside the loop
BASE_S3_DEST="s3://${S3_BUCKET}"
if [ -n "$S3_PREFIX" ]; then
  BASE_S3_DEST="${BASE_S3_DEST}/${S3_PREFIX}"
fi

AWS_ARGS=()
if [ -n "$S3_ENDPOINT" ]; then
  AWS_ARGS+=("--endpoint-url" "$S3_ENDPOINT")
fi

# Optimization: Use pigz for parallel compression if available, fallback to gzip
if command -v pigz >/dev/null 2>&1; then
  COMPRESS_CMD="pigz"
else
  COMPRESS_CMD="gzip"
fi

for db in "${DBS[@]}"; do
  # Trim whitespace (use bash built-ins instead of subshell/sed for performance)
  db="${db#"${db%%[![:space:]]*}"}"
  db="${db%"${db##*[![:space:]]}"}"
  if [ -n "$db" ]; then
      # Sanitize DB name for filename to prevent directory traversal or weird S3 keys
      SAFE_DB_NAME="${db//[^a-zA-Z0-9._-]/_}"
      FILE_NAME="${SAFE_DB_NAME}_${DATE}.sql.gz"

      echo "Streaming backup of database: $db to ${BASE_S3_DEST}/$FILE_NAME..."

      # Stream backup directly to S3 without local buffering
      # set -o pipefail ensures we catch pg_dump errors
      # Optimization: Use $COMPRESS_CMD (pigz or gzip) to speed up compression
      PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -- "$db" | "$COMPRESS_CMD" | AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" aws s3 cp - "${BASE_S3_DEST}/$FILE_NAME" "${AWS_ARGS[@]}"
      echo "Finished backing up $db."
    fi
  done

echo "Backup process completed successfully."
