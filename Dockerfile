FROM postgres:18-alpine

# Install AWS CLI, bash, and pigz for parallel compression
RUN apk add --no-cache \
    aws-cli \
    bash \
    pigz

# Copy the backup script
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh

ENTRYPOINT ["/usr/local/bin/backup.sh"]
