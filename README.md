# Postgres S3 Backup (Multi-Database Support)

A custom Docker image to back up one or more PostgreSQL databases to an S3-compatible storage service. It uses `pg_dump` from official PostgreSQL Alpine images and uploads the compressed archives (`.sql.gz`) via the AWS CLI.

## Features
- Automatically backs up **all** databases if `BACKUP_ALL_DATABASES=true` is set.
- Backs up *multiple* databases if provided as a comma-separated list in `POSTGRES_DB`.
- Supports any S3-compatible service (AWS S3, MinIO, Cloudflare R2, ArvanCloud, etc.)
- Uses the native `postgres:18-alpine` client.

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `BACKUP_ALL_DATABASES` | If `true` or `1`, dynamically fetches all available DBs and backs them up. | `false` | No |
| `POSTGRES_HOST` | Hostname of the database server | `localhost` | No |
| `POSTGRES_PORT` | Port of the database server | `5432` | No |
| `POSTGRES_USER` | Username to connect with | | **Yes** |
| `POSTGRES_PASSWORD` | Password for the database user | | **Yes** |
| `POSTGRES_DB` | Comma-separated list of databases to dump | | No |
| `S3_BUCKET` | S3 bucket name | | **Yes** |
| `S3_PREFIX` | S3 bucket path (folder) | `""` | No |
| `S3_ENDPOINT`| Custom S3 endpoint URL | `""` | No |
| `S3_ACCESS_KEY_ID` | AWS/S3 access key | | **Yes** |
| `S3_SECRET_ACCESS_KEY` | AWS/S3 secret key | | **Yes** |
| `S3_REGION` | AWS/S3 region | `us-east-1` | No |

**Note on Docker Secrets:**
To avoid passing sensitive information in plain text environment variables, you can append `_FILE` to `POSTGRES_USER`, `POSTGRES_PASSWORD`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY`. The script will dynamically read the contents of the specified files into the respective variables. (e.g. `POSTGRES_PASSWORD_FILE=/run/secrets/db_password`)

## Usage

You can run this container standalone or via a Kubernetes `CronJob`. To deploy it, simply pass the required environments:

```bash
docker run --rm \
  -e POSTGRES_HOST=db.example.com \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=db1,db2,db3 \
  -e S3_BUCKET=my-backups \
  -e S3_ACCESS_KEY_ID=XXX \
  -e S3_SECRET_ACCESS_KEY=YYY \
  -e S3_ENDPOINT=https://s3.example.com \
  ghcr.io/mahdishariatzade/postgres-s3-backup:18
```

Each database specified in `POSTGRES_DB` will generate a file named `{db}_YYYY-MM-DDTHH:MM:SSZ.sql.gz` stored in your bucket at `s3://BUCKET/PREFIX/`.
