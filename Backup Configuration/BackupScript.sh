#!/bin/bash
set -euo pipefail

# ---- Arguments ----
APP="${1:-}"
RETENTION_DAYS="${2:-14}"

if [[ -z "$APP" ]]; then
  echo "Usage: $0 <app_name> [retention_days]"
  echo "Example: $0 vaultwarden 14"
  exit 1
fi

# ---- Paths ----
CFILE="/home/kscheuer/docker/$APP"
APPDATA="/srv/$APP"
DEST="/srv/backups/$APP"
DATE=$(date +%F)

# ---- Safety checks ----
if [[ ! -d "$CFILE" ]]; then
  echo "ERROR: Docker compose directory not found: $CFILE"
  exit 1
fi

if [[ ! -d "$APPDATA" ]]; then
  echo "ERROR: App data directory not found: $APPDATA"
  exit 1
fi

# ---- Logging Setup ----
LOG_TAG="backup-${APP}"

# Function to log to both console and syslog
log_message() {
    echo "$1"
    logger -t "$LOG_TAG" "$1"
}

log_message "======================================"
log_message "$APP Backup Started: $DATE"
log_message "Retention: $RETENTION_DAYS days"
log_message "======================================"


# Ensure destination directory exists
mkdir -p "$DEST"

# Check available disk space
echo "Checking disk space..."
REQUIRED_SPACE=$(du -s "$APPDATA" | cut -f1)
AVAILABLE_SPACE=$(df "$DEST" | awk 'NR==2 {print $4}')
REQUIRED_MB=$((REQUIRED_SPACE / 1024))
AVAILABLE_MB=$((AVAILABLE_SPACE / 1024))

echo "Required space: ${REQUIRED_MB}MB"
echo "Available space: ${AVAILABLE_MB}MB"

if [[ $REQUIRED_SPACE -gt $AVAILABLE_SPACE ]]; then
  log_message "WARNING: Insufficient disk space for backup!"
  log_message "Consider cleaning up old backups or freeing up space."
  exit 1
fi

# Stop the service
log_message "Stopping $APP..."
cd "$CFILE"
docker compose stop
sleep 5

# Perform backup
log_message "Beginning backup tar creation..."
START_TIME=$(date +%s)
tar -cf - "$APPDATA" | pigz > "$DEST/${APP}-${DATE}.tar.gz"
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Get backup size and log completion
BACKUP_SIZE=$(du -h "$DEST/${APP}-${DATE}.tar.gz" | cut -f1)
log_message "Backup completed: ${APP}-${DATE}.tar.gz ($BACKUP_SIZE) in ${DURATION}s"

# Restart service
log_message "Starting $APP..."
docker compose start
log_message "$APP started successfully"

# Cleanup old backups (date-based via mtime)
log_message "Cleaning up backups older than $RETENTION_DAYS days..."
OLD_BACKUPS=$(find "$DEST" -type f -name "${APP}-*.tar.gz" -mtime +"$RETENTION_DAYS" -print)
if [[ -n "$OLD_BACKUPS" ]]; then
  echo "Removing old backups:"
  log_message "$OLD_BACKUPS"
  find "$DEST" -type f -name "${APP}-*.tar.gz" -mtime +"$RETENTION_DAYS" -delete
  log_message "Old backups removed"
else
  log_message "No old backups to remove"
fi

# Final status
TOTAL_BACKUPS=$(find "$DEST" -type f -name "${APP}-*.tar.gz" | wc -l)
TOTAL_SIZE=$(du -sh "$DEST" | cut -f1)

log_message "======================================"
log_message "$APP backup completed successfully: $DATE"
log_message "Total backups for $APP: $TOTAL_BACKUPS"
log_message "Total size: $TOTAL_SIZE"
log_message "======================================"
