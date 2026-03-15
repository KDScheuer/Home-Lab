#!/bin/bash
set -euo pipefail

# ---- Arguments ----
APP="${1:-}"
RETENTION_DAYS="${2:-14}"
SECONDARY_BACKUP="${3:-false}"

if [[ -z "$APP" ]]; then
  echo "Usage: $0 <app_name> [retention_days] [secondary_backup]"
  echo "Example: $0 vaultwarden 14 true"
  echo "Example: $0 vaultwarden 14 1"
  echo "Example: $0 caddy 7 false  # No secondary backup"
  echo "Example: $0 caddy 7        # No secondary backup (default)"
  exit 1
fi

# ---- Tally Config ----
TALLY_URL="https://tally.kds-dev.com"
TALLY_KEY="11a26046916dc055bd21d78c7ccb0d5a5234ebd2f54601c91586e0b864109285"

push_metric() {
    local metric="$1"
    local value="$2"
    if [[ -n "$TALLY_KEY" ]]; then
        curl -s -X POST "$TALLY_URL/push" \
            -H "Authorization: Bearer $TALLY_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"${metric}\",\"value\":${value},\"labels\":{\"service\":\"${APP}\"}}" \
            > /dev/null
    fi
}

# ---- Paths ----
CFILE="/home/kscheuer/docker/$APP"
APPDATA="/srv/$APP"
DEST="/srv/backups/$APP"
DATE=$(date +%F)

# ---- Safety checks ----
if [[ ! -d "$CFILE" ]]; then
  echo "ERROR: Docker compose directory not found: $CFILE"
  push_metric "backup_status" "0"
  exit 1
fi

if [[ ! -d "$APPDATA" ]]; then
  echo "ERROR: App data directory not found: $APPDATA"
  push_metric "backup_status" "0"
  exit 1
fi

# ---- Logging Setup ----
LOG_TAG="backup-${APP}"

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
  push_metric "backup_status" "0"
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

# wrap tar in error handling so we can report failure to tally
if ! tar -cf - "$APPDATA" | pigz > "$DEST/${APP}-${DATE}.tar.gz"; then
  log_message "ERROR: Backup tar creation failed for $APP"
  docker compose start
  push_metric "backup_status" "0"
  exit 1
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Get backup size and log completion
BACKUP_SIZE=$(du -h "$DEST/${APP}-${DATE}.tar.gz" | cut -f1)
log_message "Backup completed: ${APP}-${DATE}.tar.gz ($BACKUP_SIZE) in ${DURATION}s"

# Restart service immediately to minimize downtime
log_message "Starting $APP..."
docker compose start
log_message "$APP started successfully"

# Copy backup to alternate location and cleanup (service now running)
if [[ "$SECONDARY_BACKUP" == "true" || "$SECONDARY_BACKUP" == "1" ]]; then
  SECONDARY_DEST="/srv/local-backups/$APP"
  mkdir -p "$SECONDARY_DEST"
  log_message "Copying backup to secondary location: $SECONDARY_DEST"
  cp "$DEST/${APP}-${DATE}.tar.gz" "$SECONDARY_DEST/"
  log_message "Secondary copy completed"

  CLEANUP_MINUTES=$(((RETENTION_DAYS * 24 * 60) - 60))
  log_message "Cleaning up secondary location backups older than $RETENTION_DAYS days (using ${CLEANUP_MINUTES} minutes)..."
  OLD_SECONDARY_BACKUPS=$(find "$SECONDARY_DEST" -type f -name "${APP}-*.tar.gz" -mmin +"$CLEANUP_MINUTES" -print)
  if [[ -n "$OLD_SECONDARY_BACKUPS" ]]; then
    log_message "Removing old secondary backups: $OLD_SECONDARY_BACKUPS"
    find "$SECONDARY_DEST" -type f -name "${APP}-*.tar.gz" -mmin +"$CLEANUP_MINUTES" -delete
    log_message "Old secondary backups removed"
  else
    log_message "No old secondary backups to remove"
  fi
else
  log_message "Secondary backup disabled - skipping secondary backup"
fi

# Cleanup old backups
CLEANUP_MINUTES=$(((RETENTION_DAYS * 24 * 60) - 60))
log_message "Cleaning up backups older than $RETENTION_DAYS days (using ${CLEANUP_MINUTES} minutes)..."
OLD_BACKUPS=$(find "$DEST" -type f -name "${APP}-*.tar.gz" -mmin +"$CLEANUP_MINUTES" -print)
if [[ -n "$OLD_BACKUPS" ]]; then
  echo "Removing old backups:"
  log_message "$OLD_BACKUPS"
  find "$DEST" -type f -name "${APP}-*.tar.gz" -mmin +"$CLEANUP_MINUTES" -delete
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

# Push success metrics to Tally
push_metric "backup_status" "1"
push_metric "backup_last_success" "$(date +%s)"
push_metric "backup_duration_seconds" "$DURATION"