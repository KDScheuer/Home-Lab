# Home Lab Backup Strategy

## Service Categorization

### Daily Backups
**All services are backed up daily with automated retention policies.**

- **VaultWarden**
  - Rationale: Secrets being lost is unacceptable - requires daily backup protection
  - Retention: 7 days

- **FileBrowser**
  - Rationale: Important documents that could be uploaded and deleted - data loss is unacceptable
  - Retention: 7 days

- **Immich**
  - Rationale: Used by family to offload pictures when storage runs out. Large application size requires reduced retention due to storage capacity limitations
  - Retention: 1 day

- **Mealie**
  - Rationale: Recipe and meal planning data - daily backups ensure minimal data loss
  - Retention: 7 days

- **AdGuardHome**
  - Rationale: DNS configuration and filtering rules - daily backup preserves custom configurations
  - Retention: 7 days

- **Caddy**
  - Rationale: Reverse proxy configuration and certificates - daily backup ensures service continuity
  - Retention: 7 days

- **Grafana**
  - Rationale: Dashboard configurations and user data - daily backup preserves custom monitoring setup
  - Retention: 7 days

- **Prometheus**
  - Rationale: Monitoring configuration and historical data - daily backup maintains observability setup
  - Retention: 7 days 

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
- **Primary Local Backup**: Application SSD backup stored in `/srv/backups/`
- **Secondary Local Backup**: Filesystem SSD backup stored in `/home/kscheuer/backups/`
- **External Copy**: External drive backup for additional redundancy

### 2+ Types of Media
- **Application SSD**: Hosts services and primary backups (`/srv/backups/`)
- **Filesystem SSD**: Hosts user data and secondary backups (`/home/kscheuer/backups/`)
- **External SSD**: Portable external drive for offsite storage

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

# Daily Backups (staggered every 30 minutes starting at midnight)
# VaultWarden - 12:00 AM daily
0 0 * * * /home/kscheuer/BackupScript.sh vaultwarden 7
# FileBrowser - 12:30 AM daily  
30 0 * * * /home/kscheuer/BackupScript.sh filebrowser 7
# Mealie - 1:00 AM daily
0 1 * * * /home/kscheuer/BackupScript.sh mealie 7
# AdGuardHome - 1:30 AM daily
30 1 * * * /home/kscheuer/BackupScript.sh adguardhome 7
# Caddy - 2:00 AM daily
0 2 * * * /home/kscheuer/BackupScript.sh caddy 7
# Grafana - 2:30 AM daily
30 2 * * * /home/kscheuer/BackupScript.sh grafana 7
# Prometheus - 3:00 AM daily
0 3 * * * /home/kscheuer/BackupScript.sh prometheus 7
# Immich - 3:30 AM daily (1-day retention due to size)
30 3 * * * /home/kscheuer/BackupScript.sh immich 1
```

**Verify crontab configuration:**
```bash
sudo crontab -l
```

### Initial Backup Execution

**Run initial backups to verify functionality before relying on automated schedule:**

```bash
# Daily backup services
/home/kscheuer/BackupScript.sh vaultwarden 7
/home/kscheuer/BackupScript.sh filebrowser 7
/home/kscheuer/BackupScript.sh immich 1
/home/kscheuer/BackupScript.sh mealie 7
/home/kscheuer/BackupScript.sh adguardhome 7
/home/kscheuer/BackupScript.sh caddy 7
/home/kscheuer/BackupScript.sh grafana 7
/home/kscheuer/BackupScript.sh prometheus 7
```

### Monitoring and Maintenance

**Regular tasks to ensure backup system health:**

- Monitor `/var/log/syslog` for backup completion logs
- Verify backup sizes and retention policies
- Test backup restoration procedures quarterly
- Monitor available disk space in `/srv/backups/`
- Update external drive backups monthly
