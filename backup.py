#!/usr/bin/env python3

import datetime
import os
import subprocess
import logging
import tarfile
import time
import requests

TALLY_URL   = "http://192.168.50.200:9200"
TALLY_KEY   = os.getenv("TALLY_KEY")
COMPOSE_DIR = "/home/kscheuer/docker/"
DATA_DIR    = "/srv/"
BACKUP_DIR  = "/srv/backups/"
RETENTION   = 28
TARGETS     = [
    "vaultwarden",
    "filebrowser",
    "mealie",
    "caddy",
    "grafana",
    "prometheus",
    "immich",
    "adguardhome"
]

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def validate_paths(service):
    compose_path = os.path.join(COMPOSE_DIR, service)
    data_path    = os.path.join(DATA_DIR, service)

    if not os.path.exists(compose_path):
        raise FileNotFoundError(f"Compose file for {service} not found at {compose_path}")

    if not os.path.exists(data_path):
        raise FileNotFoundError(f"Data directory for {service} not found at {data_path}")

def get_dir_size(path):
    total = 0
    for dirpath, _, filenames in os.walk(path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            if not os.path.islink(fp):
                total += os.path.getsize(fp)
    return total

def validate_space_available(service):
    data_path = os.path.join(DATA_DIR, service)
    required_space = get_dir_size(data_path)
    stat = os.statvfs(BACKUP_DIR)
    available_space = stat.f_frsize * stat.f_bavail
    required_mb = required_space // (1024 * 1024)
    available_mb = available_space // (1024 * 1024)
    logger.info(f"Required space: {required_mb}MB, Available space: {available_mb}MB")
    if available_space < required_space:
        raise Exception(f"Not enough space available for backup. Required: {required_mb}MB, Available: {available_mb}MB")

def manage_service(service, state):
    compose_path = os.path.join(COMPOSE_DIR, service)
    try:
        subprocess.run(["docker", "compose", state], cwd=compose_path, check=True)
    except subprocess.CalledProcessError as e:
        raise Exception(f"Failed to {state} service {service}: {e}")
    
def backup_service(service):
    date = datetime.datetime.now().strftime("%Y-%m-%d")
    dest = os.path.join(BACKUP_DIR, service)
    os.makedirs(dest, exist_ok=True)
    backup_path = os.path.join(dest, f"{service}-{date}.tar.gz")
    try:
        with tarfile.open(backup_path, "w:gz") as tar:
            tar.add(os.path.join(COMPOSE_DIR, service), arcname="compose")
            tar.add(os.path.join(DATA_DIR, service), arcname="data")
    except Exception as e:
        raise Exception(f"Failed to create backup for {service}: {e}")
    size = os.path.getsize(backup_path) / (1024 * 1024)
    logger.info(f"Backup created: {backup_path} ({size:.1f}MB)")
    return backup_path

def cleanup_old_backups(service):
    dest = os.path.join(BACKUP_DIR, service)
    if not os.path.isdir(dest):
        return
    now = datetime.datetime.now()
    for filename in os.listdir(dest):
        if filename.endswith(".tar.gz"):
            file_path = os.path.join(dest, filename)
            file_time = datetime.datetime.fromtimestamp(os.path.getmtime(file_path))
            if (now - file_time).days > RETENTION:
                try:
                    os.remove(file_path)
                    logger.info(f"Deleted old backup: {file_path}")
                except Exception as e:
                    logger.error(f"Failed to delete old backup {file_path}: {e}")

def push_metric(name: str, value: float, metric_type: str = "gauge", labels: dict = None) -> requests.Response:
    payload = {
        "name":   name,
        "value":  value,
        "type":   metric_type,
        "labels": labels if labels is not None else {},
    }
    resp = requests.post(
        f"{TALLY_URL}/push",
        headers={"Authorization": f"Bearer {TALLY_KEY}"},
        json=payload,
    )
    resp.raise_for_status()
    return resp

def main():
    date = datetime.datetime.now().strftime("%Y-%m-%d")
    logger.info("======================================")
    logger.info(f"Backup Process Started: {date}")
    logger.info(f"Retention Policy: {RETENTION} days")
    logger.info("======================================\n")
    try:
        push_metric(
            name="backup_script_running",
            value=1,
            metric_type="gauge",
            labels={"instance": "backup_script"},
        )
    except Exception as e:
        logger.warning(f"Failed to set backup progress metric: {e}")
    
    backup_successful = 1
    for service in TARGETS:
        logger.info(f"Backup started for {service}")
        backup_start_time = datetime.datetime.now()
        try:
            validate_paths(service)
            validate_space_available(service)
            logger.info(f"Stopping {service}...")
            manage_service(service, "stop")
            time.sleep(5)
            backup_service(service)
            logger.info(f"Starting {service}...")
            manage_service(service, "start")
            logger.info(f"{service} started successfully")
            duration = (datetime.datetime.now() - backup_start_time).total_seconds()
            push_metric(
                name="target_backup_status",
                value=1,
                metric_type="gauge",
                labels={"instance": service},
            )
            push_metric(
                name=f"backup_duration_seconds",
                value=duration,
                metric_type="gauge",
                labels={"instance": service},
            )
            push_metric(
                name=f"backup_last_success",
                value=int(datetime.datetime.now().timestamp()),
                metric_type="gauge",
                labels={"instance": service},
            )
            logger.info(f"{service} backup completed successfully in {duration:.1f} seconds.")
        except Exception as e:
            backup_successful = 0
            logger.error(e)
            try:
                manage_service(service, "start")
            except Exception as restart_error:
                logger.error(f"Failed to restart {service} after backup failure: {restart_error}")
            push_metric(
                name="target_backup_status",
                value=0,
                metric_type="gauge",
                labels={"instance": service},
            )
            continue

        try:
            cleanup_old_backups(service)
        except Exception as e:
            backup_successful = 0
            logger.error(f"Failed to cleanup old backups for {service}: {e}")

    try:
        script_status = 0 if backup_successful else 2
        push_metric(
            name="backup_script_running",
            value=script_status,
            metric_type="gauge",
            labels={"instance": "backup_script"},
        )
    except Exception as e:
        logger.warning(f"Failed to update backup progress metric: {e}")

    logger.info("Backup process completed for all services")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        for service in TARGETS:
            try:
                manage_service(service, "start")
            except Exception as e:
                logger.error(f"Failed to restart {service} during interruption: {e}")
        logger.info("Backup process interrupted by user")
