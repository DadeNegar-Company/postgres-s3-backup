#!/bin/bash

# Exit on explicitly thrown errors
set -e

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
  # Trim whitespace
  db=$(echo "$db" | xargs)
  if [ -n "$db" ]; then
      FILE_NAME="${db}_${DATE}.sql.gz"
      echo "Backing up database: $db to $FILE_NAME..."
      
      # Perform the dump and compress
      echo "Dumping..."
      # Use -- to prevent flag injection from $db variable
      pg_dump -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -- "$db" | gzip > "/tmp/$FILE_NAME"
      
      echo "Uploading /tmp/$FILE_NAME to S3 bucket $S3_BUCKET under prefix $S3_PREFIX"
      S3_DEST="s3://${S3_BUCKET}"
      if [ -n "$S3_PREFIX" ]; then
         S3_DEST="${S3_DEST}/${S3_PREFIX}"
      fi
      
      AWS_ARGS=()
      if [ -n "$S3_ENDPOINT" ]; then
         AWS_ARGS+=("--endpoint-url" "$S3_ENDPOINT")
      fi
      
      # Avoid eval and use proper quoting to prevent command injection
      aws s3 cp "/tmp/$FILE_NAME" "${S3_DEST}/$FILE_NAME" "${AWS_ARGS[@]}"
      
      # Clean up local file
      rm -- "/tmp/$FILE_NAME"
      echo "Finished backing up $db."
    fi
  done

echo "Backup process completed successfully."
