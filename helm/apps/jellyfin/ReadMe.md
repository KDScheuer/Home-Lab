# Jellyfin

## Deploy

```bash
cd ~/Home-Lab/helm/apps/jellyfin
kubectl apply -f ./
```

Watch the pod come up:

```bash
kubectl -n jellyfin get pods -w
```

## Verify

```bash
kubectl -n jellyfin get pods
curl -I https://jellyfin.kds-dev.com
```

---

## Migration Notes (Docker Compose → k3s)

Data was already on the Synology at `/volume1/networkShare/srv/jellyfin/` — no copy
needed. Static PVs point directly at existing paths:

```
jellyfin-config → /volume1/networkShare/srv/jellyfin/config
jellyfin-cache  → /volume1/networkShare/srv/jellyfin/cache
jellyfin-media  → /volume1/networkShare/srv/jellyfin/media
```

Stopped homelab01 container:

```bash
ssh kscheuer@homelab01 "cd ~/docker/jellyfin && docker compose down"
```

Applied manifests:

```bash
kubectl apply -f ./
```

Added DNS rewrite in AdGuard: `jellyfin.kds-dev.com → 192.168.50.120`

Updated LG TV to point directly at `192.168.50.128:8096` — TV does not work
through Traefik reverse proxy, requires direct port access.

---

## Notes

- Config, cache, and media all mount directly from NAS via static PVs
- No provisioner-generated directories — data paths are fixed and predictable
- Two services: `jellyfin-web` (ClusterIP, Traefik) and `jellyfin-direct`
  (LoadBalancer at 192.168.50.128, LG TV)
- Browser access via `https://jellyfin.kds-dev.com` through Traefik
- TV access via `192.168.50.128:8096` direct — update TV network settings if
  this IP changes
- Single replica only, Recreate strategy
- Old homelab01 container remains stopped
- Media volume sized to 3Ti — actual limit is Synology free space, not enforced
  by Kubernetes