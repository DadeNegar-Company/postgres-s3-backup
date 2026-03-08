#!/bin/bash

# Exit on explicitly thrown errors
set -e
set -o pipefail

# Secure default umask to ensure created files are only readable by the owner
umask 0077

# Load secret from file
load_secret() {
  local var="$1"
  local fileVar="${var}_FILE"
  local var_val="${!var}"
  local fileVar_val="${!fileVar}"

  if [ -n "$var_val" ] && [ -n "$fileVar_val" ]; then
    echo "Error: Both $var and $fileVar are set (but are exclusive)" >&2
    exit 1
  fi
  if [ -n "$fileVar_val" ]; then
    if [ -f "$fileVar_val" ]; then
      export "$var"="$(cat "$fileVar_val")"
    else
      echo "Error: Secret file $fileVar_val does not exist" >&2
      exit 1
    fi
  fi
}

load_secret POSTGRES_USER
load_secret POSTGRES_PASSWORD
load_secret S3_ACCESS_KEY_ID
load_secret S3_SECRET_ACCESS_KEY
load_secret AWS_ACCESS_KEY_ID
load_secret AWS_SECRET_ACCESS_KEY
load_secret S3_BUCKET
load_secret S3_ENDPOINT
load_secret S3_REGION
load_secret S3_PREFIX
load_secret POSTGRES_DB
load_secret BACKUP_ALL_DATABASES
load_secret POSTGRES_HOST
load_secret POSTGRES_PORT

# Default variables
DATE=$(date +"%Y-%m-%dT%H:%M:%SZ")
S3_PREFIX=${S3_PREFIX:-""}
POSTGRES_HOST=${POSTGRES_HOST:-"localhost"}
POSTGRES_PORT=${POSTGRES_PORT:-"5432"}

if [ -z "$POSTGRES_USER" ]; then
  echo "Error: POSTGRES_USER or POSTGRES_USER_FILE must be provided."
  exit 1
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
  echo "Error: POSTGRES_PASSWORD or POSTGRES_PASSWORD_FILE must be provided."
  exit 1
fi

if [ -z "$S3_BUCKET" ]; then
  echo "Error: S3_BUCKET or S3_BUCKET_FILE must be provided."
  exit 1
fi

echo "Starting backup process at $DATE"

export PGPASSWORD=$POSTGRES_PASSWORD

# Configure AWS CLI using standard environment variables if custom ones were provided
export AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY_ID:-$AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${S3_SECRET_ACCESS_KEY:-$AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${S3_REGION:-us-east-1}

# If BACKUP_ALL_DATABASES is set to true, fetch all databases dynamically
if [ "$BACKUP_ALL_DATABASES" = "true" ] || [ "$BACKUP_ALL_DATABASES" = "1" ]; then
  echo "BACKUP_ALL_DATABASES is set. Fetching all databases from the server..."
  DBS_LIST=$(psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;")
  # Convert the newline separated list into an array
  mapfile -t DBS <<< "$DBS_LIST"
elif [ -n "$POSTGRES_DB" ]; then
  IFS=',' read -ra DBS <<< "$POSTGRES_DB"
else
  echo "Neither POSTGRES_DB nor BACKUP_ALL_DATABASES is provided. Nothing to backup."
  exit 0
fi

for db in "${DBS[@]}"; do
  # Trim whitespace (use sed to avoid xargs parsing issues with quotes)
  db=$(echo "$db" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  if [ -n "$db" ]; then
      # Sanitize DB name for filename to prevent directory traversal or weird S3 keys
      SAFE_DB_NAME=$(echo "$db" | sed 's/[^a-zA-Z0-9._-]/_/g')
      FILE_NAME="${SAFE_DB_NAME}_${DATE}.sql.gz"
      S3_DEST="s3://${S3_BUCKET}"
      if [ -n "$S3_PREFIX" ]; then
         S3_DEST="${S3_DEST}/${S3_PREFIX}"
      fi

      AWS_ARGS=()
      if [ -n "$S3_ENDPOINT" ]; then
         AWS_ARGS+=("--endpoint-url" "$S3_ENDPOINT")
      fi

      echo "Streaming backup of database: $db to ${S3_DEST}/$FILE_NAME..."

      # Stream backup directly to S3 without local buffering
      # set -o pipefail ensures we catch pg_dump errors
      pg_dump -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -- "$db" | gzip | aws s3 cp - "${S3_DEST}/$FILE_NAME" "${AWS_ARGS[@]}"
      echo "Finished backing up $db."
    fi
  done

echo "Backup process completed successfully."
