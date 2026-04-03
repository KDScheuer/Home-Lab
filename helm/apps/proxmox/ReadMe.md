# Proxmox Ingress

Exposes the Proxmox web UI at `https://proxmox.kds-dev.com` through
Traefik with the wildcard `*.kds-dev.com` cert.

## Why

Proxmox listens on port 8006 with a self-signed cert. Without this
ingress the only way to reach the UI is `https://192.168.50.101:8006`
which requires accepting a cert warning every time and isn't linkable
from Homepage. This ingress routes `proxmox.kds-dev.com` through
Traefik so the frontend gets the valid wildcard cert while Traefik
handles the self-signed cert on the backend via `insecureSkipVerify`.

## Deploy

```bash
cd ~/Home-Lab/helm/apps/proxmox
kubectl apply -f proxmox-ingress.yml
```

Add DNS rewrite in AdGuard: `proxmox.kds-dev.com → 192.168.50.120`

## Notes

- Reuses the `insecure-nas` ServersTransport from `helm/apps/synology/`
  which handles self-signed backend certs for any internal service
- Points at node1 (`192.168.50.101`) — if node1 is down access Proxmox
  directly via node2 or node3 IP on port 8006
- Proxmox cluster management works from any node so node1 is just a
  convenient default, not a single point of failure for the cluster itself