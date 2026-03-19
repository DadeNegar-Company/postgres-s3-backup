#!/bin/bash

# Exit on explicitly thrown errors
set -e
set -o pipefail

# Secure default umask to ensure created files are only readable by the owner
umask 0077

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
  local var="$1"
  local fileVar="${var}_FILE"
  local def="${2:-}"

  if [[ -v "$var" ]] && [[ -v "$fileVar" ]]; then
    echo "Error: Both $var and $fileVar are set (but are exclusive)" >&2
    exit 1
  fi

  local val="$def"
  if [[ -v "$var" ]]; then
    val="${!var}"
  elif [[ -v "$fileVar" ]]; then
    local filePath="${!fileVar}"
    if [ -f "$filePath" ]; then
      val="$(cat "$filePath")"
    else
      echo "Error: Secret file $filePath does not exist" >&2
      exit 1
    fi
  fi

  export "$var"="$val"
  unset "$fileVar"
}

# Default variables
DATE=$(date +"%Y-%m-%dT%H:%M:%SZ")

file_env 'S3_PREFIX' ''
file_env 'POSTGRES_HOST' 'localhost'
file_env 'POSTGRES_PORT' '5432'
file_env 'POSTGRES_USER'
file_env 'POSTGRES_PASSWORD'
file_env 'S3_BUCKET'
file_env 'S3_ACCESS_KEY_ID'
file_env 'AWS_ACCESS_KEY_ID'
file_env 'S3_SECRET_ACCESS_KEY'
file_env 'AWS_SECRET_ACCESS_KEY'
file_env 'S3_REGION' 'us-east-1'
file_env 'S3_ENDPOINT'
file_env 'BACKUP_ALL_DATABASES'
file_env 'POSTGRES_DB'

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
if [ -n "$S3_ACCESS_KEY_ID" ]; then
  export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID"
fi
if [ -n "$S3_SECRET_ACCESS_KEY" ]; then
  export AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY"
fi
export AWS_DEFAULT_REGION="$S3_REGION"

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
