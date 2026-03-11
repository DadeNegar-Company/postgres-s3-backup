#!/bin/bash

# Exit on explicitly thrown errors
set -e
set -o pipefail

# Secure default umask to ensure created files are only readable by the owner
umask 0077

# Helper function to load secrets from files
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local val="${!var}"
  local fileVal="${!fileVar}"

  if [ -n "$val" ] && [ -n "$fileVal" ]; then
    printf "Error: Both %s and %s are set (but are exclusive)\n" "$var" "$fileVar"
    exit 1
  fi
  if [ -n "$val" ]; then
    export "$var"="$val"
  elif [ -n "$fileVal" ]; then
    if [ ! -f "$fileVal" ]; then
      printf "Error: Secret file %s does not exist\n" "$fileVal"
      exit 1
    fi
    export "$var"="$(cat "$fileVal")"
  fi
}

file_env "POSTGRES_USER"
file_env "POSTGRES_PASSWORD"
file_env "S3_BUCKET"
file_env "POSTGRES_DB"
file_env "AWS_ACCESS_KEY_ID"
file_env "AWS_SECRET_ACCESS_KEY"

# Default variables
DATE=$(date +"%Y-%m-%dT%H:%M:%SZ")
S3_PREFIX=${S3_PREFIX:-""}
POSTGRES_HOST=${POSTGRES_HOST:-"localhost"}
POSTGRES_PORT=${POSTGRES_PORT:-"5432"}

if [ -z "$POSTGRES_USER" ]; then
  printf "Error: POSTGRES_USER must be provided.\n"
  exit 1
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
  printf "Error: POSTGRES_PASSWORD must be provided.\n"
  exit 1
fi

if [ -z "$S3_BUCKET" ]; then
  printf "Error: S3_BUCKET must be provided.\n"
  exit 1
fi

printf "Starting backup process at %s\n" "$DATE"

export PGPASSWORD=$POSTGRES_PASSWORD

# Configure AWS CLI using standard environment variables if custom ones were provided
export AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY_ID:-$AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${S3_SECRET_ACCESS_KEY:-$AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${S3_REGION:-us-east-1}

# If BACKUP_ALL_DATABASES is set to true, fetch all databases dynamically
if [ "$BACKUP_ALL_DATABASES" = "true" ] || [ "$BACKUP_ALL_DATABASES" = "1" ]; then
  printf "BACKUP_ALL_DATABASES is set. Fetching all databases from the server...\n"
  DBS_LIST=$(psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;")
  # Convert the newline separated list into an array
  mapfile -t DBS <<< "$DBS_LIST"
elif [ -n "$POSTGRES_DB" ]; then
  IFS=',' read -ra DBS <<< "$POSTGRES_DB"
else
  printf "Neither POSTGRES_DB nor BACKUP_ALL_DATABASES is provided. Nothing to backup.\n"
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

      printf "Streaming backup of database: %s to %s/%s...\n" "$db" "$S3_DEST" "$FILE_NAME"

      # Stream backup directly to S3 without local buffering
      # set -o pipefail ensures we catch pg_dump errors
      pg_dump -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -- "$db" | gzip | aws s3 cp - "${S3_DEST}/$FILE_NAME" "${AWS_ARGS[@]}"
      printf "Finished backing up %s.\n" "$db"
    fi
  done

printf "Backup process completed successfully.\n"
