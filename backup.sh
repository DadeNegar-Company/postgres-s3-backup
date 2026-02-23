#!/bin/bash

# Exit on explicitly thrown errors
set -e
set -o pipefail

# Default variables
DATE=$(date +"%Y-%m-%dT%H:%M:%SZ")
S3_PREFIX=${S3_PREFIX:-""}
POSTGRES_HOST=${POSTGRES_HOST:-"localhost"}
POSTGRES_PORT=${POSTGRES_PORT:-"5432"}

if [ -z "$POSTGRES_USER" ]; then
  echo "Error: POSTGRES_USER must be provided."
  exit 1
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
  echo "Error: POSTGRES_PASSWORD must be provided."
  exit 1
fi

if [ -z "$S3_BUCKET" ]; then
  echo "Error: S3_BUCKET must be provided."
  exit 1
fi

echo "Starting backup process at $DATE"

export PGPASSWORD=$POSTGRES_PASSWORD

# Configure AWS CLI using standard environment variables if custom ones were provided
export AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY_ID:-$AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${S3_SECRET_ACCESS_KEY:-$AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${S3_REGION:-us-east-1}

# If POSTGRES_DB is provided, backup specific comma-separated databases.
# Otherwise, skip or maybe define another behavior.
if [ -n "$POSTGRES_DB" ]; then
  # Prepare S3 destination and AWS arguments once
  S3_DEST="s3://${S3_BUCKET}"
  if [ -n "$S3_PREFIX" ]; then
     S3_DEST="${S3_DEST}/${S3_PREFIX}"
  fi

  AWS_ARGS=""
  if [ -n "$S3_ENDPOINT" ]; then
     AWS_ARGS="--endpoint-url $S3_ENDPOINT"
  fi

  IFS=',' read -ra DBS <<< "$POSTGRES_DB"
  for db in "${DBS[@]}"; do
    # Trim whitespace
    db=$(echo "$db" | xargs)
    if [ -n "$db" ]; then
      FILE_NAME="${db}_${DATE}.sql.gz"
      echo "Backing up database: $db to $FILE_NAME..."
      
      # PERFORMANCE OPTIMIZATION (Bolt ⚡):
      # Streaming the dump directly to S3 via a pipe provides several benefits:
      # 1. Reduces Disk I/O: No temporary files are written to or read from disk.
      # 2. Parallel Processing: pg_dump, gzip, and aws s3 cp run concurrently,
      #    allowing the upload to start immediately as data is produced.
      # 3. Memory Efficiency: Only small buffers are held in memory.
      # 4. Zero Disk Space: No risk of running out of disk space for large backups.
      echo "Dumping and uploading to S3..."
      pg_dump -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" "$db" | gzip | \
      eval "aws s3 cp - ${S3_DEST}/$FILE_NAME $AWS_ARGS"
      
      echo "Finished backing up $db."
    fi
  done
else
  echo "POSTGRES_DB is not provided. Nothing to backup."
fi

echo "Backup process completed successfully."
