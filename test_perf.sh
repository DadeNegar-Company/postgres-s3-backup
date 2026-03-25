#!/bin/bash
DATE=$(date +"%Y-%m-%dT%H:%M:%SZ")
BASE_S3_DEST="s3://testbucket"

for i in {1..1000}; do
  db="test_db_$i"
  db="${db#"${db%%[![:space:]]*}"}"
  db="${db%"${db##*[![:space:]]}"}"
  if [ -n "$db" ]; then
      SAFE_DB_NAME="${db//[^a-zA-Z0-9._-]/_}"
      FILE_NAME="${SAFE_DB_NAME}_${DATE}.sql.gz"
      echo "Streaming backup of database: $db to ${BASE_S3_DEST}/$FILE_NAME..." > /dev/null
  fi
done
