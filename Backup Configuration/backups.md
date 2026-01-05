# Home Lab Backup Strategy

## Service Categorization

### Daily Backups
**Critical services requiring daily protection due to high data sensitivity and change frequency.**

- **VaultWarden**
  - Rationale: Secrets being lost is unacceptable
  - Retention: 14 days

- **FileBrowser**
  - Rationale: Important documents that could be uploaded and deleted - data loss is unacceptable
  - Retention: 14 days

### Weekly Backups
**Services with moderate criticality where weekly backups provide sufficient data protection.**

- **Immich**
  - Rationale: Used by family to offload pictures when storage runs out. Since oldest pictures are deleted first and syncing happens automatically, weekly backups reduce risk to acceptable levels
  - Retention: 7 days

- **Mealie**
  - Rationale: Small application storing recipes and meal plans. Data loss would be inconvenient, and due to small size and minimal impact on backup capacity, weekly backups are justified. Will be reassessed if data grows significantly
  - Retention: 14 days

- **AdGuardHome**
  - Rationale: Primarily configuration backups rather than data. Weekly schedule is sufficient for configuration preservation
  - Retention: 14 days

- **Caddy**
  - Rationale: Primarily configuration backups rather than data. Weekly schedule is sufficient for configuration preservation
  - Retention: 14 days

- **Grafana**
  - Rationale: Primarily configuration backups rather than data. Weekly schedule is sufficient for configuration preservation
  - Retention: 14 days

- **Prometheus**
  - Rationale: Primarily configuration backups rather than data. Weekly schedule is sufficient for configuration preservation
  - Retention: 14 days 

### No Backups
**Services excluded from backup strategy due to size constraints or easy recoverability.**

- **Jellyfin**
  - Rationale: Due to large data size and the fact that media is easily rebuildable, backups are excluded. If sufficient storage becomes available in the future, backups will be configured to avoid the inconvenience of a rebuild during disaster recovery

- **Homepage**
  - Rationale: Static site serving as home lab dashboard. Source files in GitHub repository provide sufficient backup

- **Tailscale**
  - Rationale: Deployed as daemon on hosting server. Easy to reconfigure and does not warrant backup. Setup documentation in this repository is sufficient for disaster recovery 


## Backup Infrastructure

**Following the 3-2-1 backup rule for critical data protection:**

### 3 Copies
- **Production Copy**: Live data in running services
- **Local Backup**: On-host backup stored in `/srv/backups/`
- **External Copy**: External drive backup for additional redundancy

### 2 Types of Media
- **Local SSD**: Host system storage
- **External SSD**: Portable external drive

### 1 Offsite Location
- **Secure Storage**: External SSD stored in fireproof, waterproof safe 

## Implementation

### Backup Script Setup

**Generic backup script supporting CLI execution and cron scheduling with configurable retention periods.**

```bash
# Create and configure backup script
vi ~/BackupScript.sh
chmod +x ~/BackupScript.sh

# Install parallel gzip for faster compression
sudo dnf install pigz
```

```bash
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
```

### Automated Scheduling

**Configure root crontab for automated backup execution:**

```bash
# Switch to root user and edit crontab
sudo su
crontab -e
```

**Crontab configuration:**

```bash
# Homelab Backup Schedule
#   Arg1=AppName 
#   Arg2=RetentionDays

# Daily Backups
# VaultWarden - 12:00 AM daily
0 0 * * * /home/kscheuer/BackupScript.sh vaultwarden 14
# FileBrowser - 12:30 AM daily  
30 0 * * * /home/kscheuer/BackupScript.sh filebrowser 14

# Weekly Backups
# Immich      - Sunday 2:00 AM
0 2 * * 0 /home/kscheuer/BackupScript.sh immich 7
# Mealie      - Sunday 3:15 AM
15 3 * * 0 /home/kscheuer/BackupScript.sh mealie 14
# AdGuardHome - Sunday 3:30 AM
30 3 * * 0 /home/kscheuer/BackupScript.sh adguardhome 14
# Caddy       - Sunday 3:45 AM
45 3 * * 0 /home/kscheuer/BackupScript.sh caddy 14
# Grafana     - Sunday 4:00 AM
0 4 * * 0 /home/kscheuer/BackupScript.sh grafana 14
# Prometheus  - Sunday 4:15 AM
15 4 * * 0 /home/kscheuer/BackupScript.sh prometheus 14
```

**Verify crontab configuration:**
```bash
sudo crontab -l
```

### Initial Backup Execution

**Run initial backups to verify functionality before relying on automated schedule:**

```bash
# Daily backup services
/home/kscheuer/BackupScript.sh vaultwarden 14
/home/kscheuer/BackupScript.sh filebrowser 14

# Weekly backup services
/home/kscheuer/BackupScript.sh immich 7
/home/kscheuer/BackupScript.sh mealie 14
/home/kscheuer/BackupScript.sh adguardhome 14
/home/kscheuer/BackupScript.sh caddy 14
/home/kscheuer/BackupScript.sh grafana 14
/home/kscheuer/BackupScript.sh prometheus 14
```

### Monitoring and Maintenance

**Regular tasks to ensure backup system health:**

- Monitor `/var/log/syslog` for backup completion logs
- Verify backup sizes and retention policies
- Test backup restoration procedures quarterly
- Monitor available disk space in `/srv/backups/`
- Update external drive backups monthly
