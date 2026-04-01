# Vaultwarden

## Deploy

```bash
cd ~/Home-Lab/helm/apps/vaultwarden
```

Create the namespace first — secret creation fails without it:

```bash
kubectl apply -f namespace.yml
```

Create the admin token secret. Token is in `.env` on homelab01 at `~/docker/vaultwarden/.env`:

```bash
kubectl create secret generic vaultwarden-secret \
  --namespace vaultwarden \
  --from-literal=admin-token=<token from .env>
```

Apply everything:

```bash
kubectl apply -f ./
```

## Verify

```bash
kubectl -n vaultwarden get pods
curl -I https://vaultwarden.kds-dev.com
```

---

## Migration Notes (Docker Compose → k3s)

Ran on homelab01:

```bash
cd ~/docker/vaultwarden
docker compose down
cp -r /srv/vaultwarden /mnt/synology/srv/vaultwarden
```

Applied manifests to create the PVC — let the NFS provisioner generate the directory:

```bash
kubectl apply -f ./
```

Scaled down before copying data into the provisioner-generated directory:

```bash
kubectl -n vaultwarden scale deployment vaultwarden --replicas=0
```

Copied existing data from `/mnt/synology/srv/vaultwarden/data/` into the provisioner
directory — found the generated path with `ls /mnt/synology/srv/`:

```bash
cp -r /mnt/synology/srv/vaultwarden/data/* \
  /mnt/synology/srv/vaultwarden-vaultwarden-data-pvc-beff378e-d33c-4b04-8d81-20662271d20b/
```

Scaled back up:

```bash
kubectl -n vaultwarden scale deployment vaultwarden --replicas=1
```

Added DNS rewrite in AdGuard: `vaultwarden.kds-dev.com → 192.168.50.120`

Verified:

```bash
nslookup vaultwarden.kds-dev.com
curl -I https://vaultwarden.kds-dev.com
```

Logged in via browser — all passwords present.

---

## Notes

- Data lives at `/volume1/networkShare/srv/` in the provisioner-generated directory
- Secret is not in Git — recreate from `.env` on homelab01 if cluster is rebuilt
- IngressRoute uses `tls: {}` to pick up the default wildcard cert from Traefik
- Single replica only — SQLite on NFS is not safe with multiple writers
- Old homelab01 container remains stopped