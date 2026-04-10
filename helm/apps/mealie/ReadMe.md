# Mealie

## Deploy

```bash
cd ~/Home-Lab/helm/apps/mealie
```

Create namespace first:

```bash
kubectl apply -f namespace.yml
```

Create database credentials secret. Credentials from `.env` on homelab01
at `~/docker/mealie/.env`:

```bash
kubectl create secret generic mealie-secret \
  --namespace mealie \
  --from-literal=postgres-user=mealie \
  --from-literal=postgres-password=mealie
```

Apply storage and start Postgres only — do not start Mealie until
database is restored:

```bash
kubectl apply -f pv.yml
kubectl apply -f pvc.yml
kubectl apply -f deployment-postgres.yml
kubectl apply -f ingress.yml
```

Wait for Postgres to be Running:

```bash
kubectl -n mealie get pods -w
```

## Restore Database

Copy dump into the postgres PV directory — do NOT leave it there after
restore or Postgres will refuse to initialize on a fresh deploy:

```bash
cp /mnt/synology/srv/backups/mealie-backup-YYYYMMDD.sql \
  /mnt/synology/srv/mealie/postgres/
```

Restore from inside the pod:

```bash
kubectl -n mealie exec deployment/mealie-postgres -- \
  psql -U mealie -d mealie \
  -f /var/lib/postgresql/data/mealie-backup-YYYYMMDD.sql
```

Clean up after restore:

```bash
rm /mnt/synology/srv/mealie/postgres/mealie-backup-YYYYMMDD.sql
```

Deploy Mealie:

```bash
kubectl apply -f deployment-mealie.yml
```

Watch all pods come up:

```bash
kubectl -n mealie get pods -w
```

## Verify

Add DNS rewrite in AdGuard: `mealie.kds-dev.com → 192.168.0.120`

```bash
curl -I https://mealie.kds-dev.com
```

Log in and confirm recipes are present.

---

## Migration Notes (Docker Compose → k3s)

Took pg_dump while Mealie was still running:

```bash
docker exec mealie-postgres pg_dump \
  -U $POSTGRES_USER mealie > ~/mealie-backup-$(date +%Y%m%d).sql
```

Created NAS directories and copied data:

```bash
mkdir -p /mnt/synology/srv/mealie/data
mkdir -p /mnt/synology/srv/mealie/postgres
cp -r /srv/mealie/data/* /mnt/synology/srv/mealie/data/
cp ~/mealie-backup-20260403.sql \
  /mnt/synology/srv/backups/mealie-backup-20260403.sql
```

Stopped containers:

```bash
cd ~/docker/mealie && docker compose down
```

Deployed Postgres, restored database, then deployed Mealie.

---

## Storage

Static PVs pointing directly at existing NAS paths:

```
mealie-data      → /volume1/networkShare/srv/mealie/data
mealie-postgres  → /volume1/networkShare/srv/mealie/postgres
```

---

## Notes

- Both pods run as UID 1024 / GID 100 to match NAS `all_squash` mapping
- Uses standard `postgres:15` image — no custom image required
- Mealie data directory owned by UID 911 on homelab01 — becomes 1024/100
  on NAS via `all_squash`, which is what the pod runs as
- Postgres on NFS is officially unsupported but acceptable for this
  homelab — see Immich runbook for full reasoning
- Single replica on both deployments, Recreate strategy
- Secret is not in Git — recreate from `.env` on homelab01 if cluster
  is rebuilt
- IngressRoute uses `tls: {}` for wildcard cert via Traefik default TLS store
- Old homelab01 containers remain stopped
- pg_dump backup stored at `/volume1/networkShare/srv/backups/`