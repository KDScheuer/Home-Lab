# Immich

## Deploy

```bash
cd ~/Home-Lab/helm/apps/immich
```

Create namespace first — secret creation fails without it:

```bash
kubectl apply -f namespace.yml
```

Create database credentials secret. Credentials are in `.env` on homelab01
at `~/docker/immich/.env`:

```bash
kubectl create secret generic immich-secret \
  --namespace immich \
  --from-literal=db-password=postgres \
  --from-literal=db-username=postgres
```

Apply PVs and PVCs — these must exist before Postgres starts:

```bash
kubectl apply -f pv.yml
kubectl apply -f pvc.yml
```

Start Postgres and Redis only first — do not start the server until the
database is restored:

```bash
kubectl apply -f deployment-postgres.yml
kubectl apply -f services.yml
```

Wait for Postgres to be Running:

```bash
kubectl -n immich get pods -w
```

## Restore Database

Copy the pg_dump from NAS backups into the Postgres PV directory so the
pod can reach it. Do NOT put it in the postgres data directory root —
Postgres will refuse to initialize if the data directory is not empty:

```bash
# copy dump into photos dir temporarily (not postgres data dir)
cp /mnt/synology/srv/backups/immich-backup-YYYYMMDD.sql \
   /mnt/synology/srv/immich/postgres/
```

Restore from inside the pod:

```bash
kubectl -n immich exec deployment/immich-postgres -- \
  psql -U postgres -d immich \
  -f /var/lib/postgresql/data/immich-backup-YYYYMMDD.sql
```

Output should be all `CREATE`, `INSERT`, `ALTER`, `COPY` lines — no `ERROR`.
Verify tables exist:

```bash
kubectl -n immich exec deployment/immich-postgres -- \
  psql -U postgres -d immich -c "\dt" | head -20
```

Remove the dump from the postgres directory after restore:

```bash
rm /mnt/synology/srv/immich/postgres/immich-backup-YYYYMMDD.sql
```

## Deploy Remaining Services

```bash
kubectl apply -f deployment-redis.yml
kubectl apply -f deployment-server.yml
kubectl apply -f deployment-ml.yml
kubectl apply -f ingress.yml
```

Watch all pods come up — machine learning takes longer as it downloads
models on first start:

```bash
kubectl -n immich get pods -w
```

Expected healthy state:

```
immich-machine-learning   1/1   Running
immich-postgres           1/1   Running
immich-redis              1/1   Running
immich-server             1/1   Running
```

## Verify

Add DNS rewrite in AdGuard: `immich.kds-dev.com → 192.168.50.120`

```bash
curl -I https://immich.kds-dev.com
```

Log in via browser and confirm photos are visible. Thumbnail regeneration
runs in the background — photos appear progressively, this is normal.

---

## Migration Notes (Docker Compose → k3s)

Took pg_dump while Immich was still running on homelab01 — do not skip
this step, it must happen before stopping the containers:

```bash
cd ~/docker/immich
docker exec immich_postgres pg_dump \
  -U postgres immich > ~/immich-backup-$(date +%Y%m%d).sql
```

Verified dump size (408MB, 523k lines) before proceeding.

Stopped containers:

```bash
docker compose down
```

Created NAS directories:

```bash
mkdir -p /mnt/synology/srv/immich/postgres
mkdir -p /mnt/synology/srv/immich/photos
mkdir -p /mnt/synology/srv/immich/model-cache
```

Copied photos from homelab01 to NAS:

```bash
cp -r /srv/immich/photos/* /mnt/synology/srv/immich/photos/
```

Deployed Postgres, restored database, then deployed remaining services.
All pods Running, photos visible in browser on first login.

---

## Gotchas

**Postgres chown failure on startup**
Postgres tries to `chown` its data directory to UID 999 on startup. NFS
with `all_squash` blocks this. Fix: add `securityContext` to the Postgres
deployment to run as UID 1024 / GID 100 matching the NAS mapped user:

```yaml
securityContext:
  runAsUser: 1024
  runAsGroup: 100
  fsGroup: 100
```

**Postgres refuses to initialize if data directory is not empty**
Putting the pg_dump file inside the postgres data directory causes Postgres
to error on init: `directory exists but is not empty`. Put the dump file
somewhere else accessible to the pod — the photos PV works fine as a
staging location.

**Server crashes with `corrupted migrations` error**
The `v2` Docker tag is a floating tag that advances with each release.
The database schema may be newer than the pinned image version you specify.
If the server logs show:
```
corrupted migrations: previously executed migration XXXXXXX-SomeMigration is missing
```
The fix is to use the latest Immich release tag rather than an older pinned
version. Check https://github.com/immich-app/immich/releases for current
version and update both server and ML images to match.

**exec into Postgres pod fails with `container not found`**
This happens when the pod is in CrashLoopBackOff — you cannot exec into a
crashing container. Fix the underlying crash first, wait for the pod to be
`1/1 Running`, then exec. The container name in the pod is `postgres`.

**Postgres on NFS — officially unsupported**
Immich's own documentation states network shares are not supported for the
database. The risk is NFS file locking unreliability under high write load
which can cause WAL corruption. For this homelab deployment the risk is
acceptable because:
- Single writer only (replicas: 1, Recreate strategy)
- Local gigabit LAN NFS — not cloud NFS
- Synology is a real NAS, not a Linux share
- Write frequency is low after initial import
- pg_dump backups provide a clean recovery path
- Photos are stored separately and are never at risk

If corruption occurs: restore from pg_dump backup. Photos are unaffected.

**Image version mismatch between server and ML**
Server and machine learning must always be on the same version. If you
update one, update both. Mismatched versions cause API errors.

---

## Storage

All data stored on Synology NAS via static PVs:

```
immich-postgres    → /volume1/networkShare/srv/immich/postgres
immich-photos      → /volume1/networkShare/srv/immich/photos
immich-model-cache → /volume1/networkShare/srv/immich/model-cache
```

Redis has no persistent storage — it is a cache/queue only and starts
fresh on every restart with no data loss.

---

## Notes

- Must use `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0`
  — the Immich-specific Postgres image with pgvecto.rs for ML vector search.
  Do not replace with standard postgres image.
- Server and ML image versions must match — pin both to the same tag
- Current version: `v2.6.3` — check releases before rebuilding
- Secret is not in Git — recreate from `.env` on homelab01 if cluster is rebuilt
- Single replica on all deployments, Recreate strategy
- IngressRoute uses `tls: {}` for wildcard cert via Traefik default TLS store
- Old homelab01 containers remain stopped
- pg_dump backup stored at `/volume1/networkShare/srv/backups/`