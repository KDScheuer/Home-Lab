# AdGuard Home

## Deploy

```bash
cd ~/Home-Lab/helm/apps/adguard
kubectl apply -f namespace.yml
kubectl apply -f pv-conf.yml
kubectl apply -f pv-work.yml
kubectl apply -f pvc-conf.yml
kubectl apply -f pvc-work.yml
kubectl apply -f deployment.yml
kubectl apply -f service-dns.yml
kubectl apply -f service-web.yml
kubectl apply -f ingress.yml
```

PVs must be applied before PVCs — order matters here unlike other apps.

Verify the DNS service got `192.168.0.129`:

```bash
kubectl -n adguard get svc
```

Verify DNS is working:

```bash
kubectl run dnstest --image=busybox --rm -it --restart=Never -- sh
/ # nslookup google.com 192.168.0.129
/ # nslookup vaultwarden.kds-dev.com 192.168.0.129
/ # exit
```

## Accessing the Web UI

AdGuard web UI is ClusterIP only — not directly externally accessible until DNS
rewrites are configured. Port-forward to access it:

```bash
kubectl -n adguard port-forward svc/adguard-web 3000:80
```

Open `http://localhost:3000` in browser.

Login: `KDScheuer97@gmail.com` — password in Vaultwarden.

---

## Migration Notes (Docker Compose → k3s)

Data was already on the Synology. Copied from homelab01:

```bash
cp -r /srv/adguardhome /mnt/synology/srv/
```

Static PVs point directly at existing paths:

```
adguard-conf → /volume1/networkShare/srv/adguardhome/conf
adguard-work → /volume1/networkShare/srv/adguardhome/work
```

Applied manifests in order above. Port-forwarded to access web UI and updated
DNS rewrite for `adguard.kds-dev.com → 192.168.0.120` — the `.129` IP is DNS
only, all HTTP/HTTPS goes through Traefik at `.120`.

Updated router DHCP pool DNS server to `192.168.0.129`.

---

## Notes

- `192.168.0.129` handles port 53 only — DNS queries from router and LAN clients
- `192.168.0.120` handles all web traffic including `adguard.kds-dev.com`
- All `*.kds-dev.com` DNS rewrites must point at `192.168.0.120` not `.129`
- Pod runs as UID 1024 / GID 100 to match NAS file ownership under root squash
- Two services: `adguard-dns` (LoadBalancer .129) and `adguard-web` (ClusterIP)
- Sessions blocked after failed login attempts — delete `sessions.db` on NAS
  and restart pod to clear: `rm /volume1/networkShare/srv/adguardhome/work/data/sessions.db`
- Single replica only, Recreate strategy
- Old homelab01 container remains stopped