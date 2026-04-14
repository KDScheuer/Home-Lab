# Backup Strategy

In my experience, backup processes should be as simple as possible — complexity is just more ways to fail. Since this is a homelab with no overnight usage, services are taken down during the backup window rather than attempting hot backups. Simple means I can actually trust these when I need them.
[Recovery Documents](/docs/disaster-recovery/)


## Policies

| Backup      | Type     | Frequency                 | Retention         | Notes                                                   |
|-------------|----------|---------------------------|-------------------|---------------------------------------------------------|
| Application | On-Site  | Thursday (1–5am)          | 35 Days           | Service scaled to 0 for atomic operations               |
| Application | Off-Site | 1st Saturday of Month     | 180 Days          | Latest on-site backup copied to AWS S3 Glacier          |
| Application | Offline  | Quarterly                 | 2 Recovery Points | Copied to external SSD                                  |
| Secrets     | On-Site  | Hourly (change-triggered) | 5 Recovery Points | Only copies if hash of .env has changed                 |
| Secrets     | Off-Site | Sunday (1am)              | 5 AWS Versions    | Only copies if hash of .env has changed                 |
| Secrets     | Offline  | Quarterly                 | 5 Recovery Points | Copied to external SSD                                  |
| SSH Keys    | On-Site  | Manual                    | 2 Recovery Points | Copied to NAS manually                                  |
| SSH Keys    | Off-Site | Manual                    | 2 Recovery Points | Stored in AWS Secrets Manager                           |
| SSH Keys    | Offline  | Quarterly                 | 2 Recovery Points | Copied to external SSD                                  |

---

## Application Scope
Below are what applications are being included or excluded from backups and the reasoning as to why. 
### Included
| Application    | Notes                                                  |
|----------------|--------------------------------------------------------|
| Immich         | Stores photos, cannot be lost                          |
| Vaultwarden    | Stores passwords, cannot be lost                       |
| Mealie         | Stores recipes, painful to repopulate                  |
| Synology Drive | Important documents, cannot be lost                    |
| AdGuard        | DNS rewrites and custom blocks not managed as IaC      |
| Grafana        | Custom dashboards and alerting, painful to reconfigure |

### Exlcuded
| Application    | Notes                                                          |
|----------------|----------------------------------------------------------------|
| Prometheus     | Loss of historical metrics is acceptable                       |
| Pushgateway    | Loss of historical metrics is acceptable                       |
| Jellyfin       | Large footprint of low-value media, not worth the storage cost |
| Homepage       | Fully IaC, nothing to back up                                  |

---

## Workflows

### Application — On-Site
**Job Flow:**
Cron → Scale service to 0 → Create tar.gz → Scale service up → Prune old backups

- Runs as a k3s CronJob
- Service is scaled to 0 to ensure atomic operations and prevent corruption
- pigz used for multithreaded compression
- Retention cleanup handled by the same script
- Pushes `backup_status` (bool) and `backup_last_success` (timestamp) to Pushgateway on completion

### Application — Off-Site
**Job Flow:**
Cron → Locate latest on-site tar.gz → Upload to S3 Glacier

- Runs as a k3s CronJob
- Scheduled after the on-site window closes to avoid targeting an in-progress archive
- Retention managed via S3 Lifecycle policy
- Pushes `backup_status` (bool) and `backup_last_success` (timestamp) to Pushgateway on completion

### Application — Offline
**Job Flow:**
Manual → Locate latest on-site tar.gz for each service → Copy to external SSD → Push metrics to Pushgateway

- Performed quarterly alongside secrets and SSH key offline backups
- SSD stored offsite
- Push `backup_status` (bool) and `backup_last_success` (timestamp) to Pushgateway on completion

### Secrets — On-Site
**Job Flow:**
Scheduled task → Hash .env → If changed, copy to NAS → Prune old copies

- Runs via Windows Task Scheduler on the management workstation
- All secrets centralized in a single .env to simplify restore operations
- Hash comparison ensures backups only occur when changes are present
- Retention managed by the script, retaining the last 5 copies
- Pushes `backup_status` (bool) and `backup_last_success` (timestamp) to Pushgateway on completion

### Secrets — Off-Site
**Job Flow:**
Scheduled task → Hash .env → If changed, upload to S3

- Runs via Windows Task Scheduler on the management workstation
- Hash comparison ensures uploads only occur when changes are present
- Retention managed via S3 Versioning and Lifecycle policy
- Pushes `backup_status` (bool) and `backup_last_success` (timestamp) to Pushgateway on completion

### Secrets — Offline
**Job Flow:**
Manual → Copy latest .env from NAS → Copy to external SSD → Push metrics to Pushgateway

- Performed quarterly alongside service and SSH key offline backups
- SSD stored offsite
- Push `backup_status` (bool) and `backup_last_success` (timestamp) to Pushgateway on completion

### SSH Keys — On-Site / Off-Site
**Job Flow:**
Manual → Copy key to NAS → Upload to AWS Secrets Manager

- Performed manually when keys are rotated or created
- Current and one prior version retained across all locations

### SSH Keys — Offline
**Job Flow:**
Manual → Copy current key to external SSD → Push metrics to Pushgateway

- Performed quarterly alongside service and secrets offline backups
- SSD stored offsite
- Push `backup_status` (bool) and `backup_last_success` (timestamp) to Pushgateway on completion

## Monitoring and Alerting

Each job pushes two metrics to Pushgateway on completion:
- `backup_status` — 1 (success) or 0 (failure)
- `backup_last_success` — Unix timestamp of last successful run

Prometheus scrapes Pushgateway. Grafana dashboards surface per-job status and last success time. Alerting fires on `backup_status = 0` or a stale `backup_last_success` timestamp, covering both job failures and jobs that silently stop running. Alerts are delivered via AWS SNS.
