# Synology NAS — Ingress & Drive Setup

## Overview

Provides two clean URLs for the Synology NAS through Traefik:

```
https://nas.kds-dev.com    → DSM admin portal
https://share.kds-dev.com  → Synology Drive web UI
```

Mobile access via **DS File** app (not Synology Drive app — see gotchas).

---

## Deploy

```bash
cd ~/Home-Lab/helm/apps/synology
kubectl apply -f servers-transport.yml
kubectl apply -f nas-ingress.yml
```

Add DNS rewrites in AdGuard:
```
nas.kds-dev.com   → 192.168.0.120
share.kds-dev.com → 192.168.0.120
```

Verify:

```bash
curl -I https://nas.kds-dev.com
curl -IL https://share.kds-dev.com
```

`nas` should return `HTTP/2 200`. `share` should return `307` redirecting
to `https://nas.kds-dev.com/?launchApp=SYNO.SDS.Drive.Application`.

---

## How It Works

**nas.kds-dev.com** — Traefik proxies directly to the NAS on port 5001
via a manual Endpoints object (not ExternalName — see gotchas). A
ServersTransport with `insecureSkipVerify: true` handles the NAS
self-signed cert on the backend connection. The wildcard cert covers
the Traefik frontend so the browser sees a valid cert.

**share.kds-dev.com** — Traefik applies a redirectRegex middleware that
sends the browser to the DSM Drive launch URL. Synology Drive is a DSM
application launched via query string, not a separate web server or path.

---

## NAS Configuration

### Synology Drive Server

Package Center → install **Synology Drive Server** → start the service.

In **Synology Drive Admin Console**:
- Team Folder → add **FamilyDocs** as a Team Folder
- Enable access for both user accounts

User home service must be enabled or the Drive app fails silently:

Control Panel → User & Group → Advanced → Enable user home service

### Shared Folders

```
FamilyDocs    → /volume1/FamilyDocs
               versioning: ON, 4 versions, 30 day retention
               NFS: disabled (Synology Drive protocol only)
               permissions: kscheuer R/W, kayla R/W

homes         → /volume1/homes
               auto-created when user home service is enabled
               versioning: ON, 2 versions, 30 day retention
```

### User Accounts

| User | Role | Access |
|------|------|--------|
| kscheuer | admin | all shares |
| kayla | user | FamilyDocs only |

---

## Mobile Access

**DS File app** (not Synology Drive app) works reliably for mobile access.

Connection settings in DS File:
```
Server:  192.168.0.201
Port:    5001
HTTPS:   ON
```

The **Synology Drive app** does not work — it fails silently at the
connection screen without showing a login prompt. See gotchas below.

---

## Gotchas

**ExternalName services not allowed in k3s**
Traefik on k3s blocks ExternalName service type for security reasons.
Error: `externalName services not allowed: default/nas-external`
Fix: use a manual `Service` + `Endpoints` object instead:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nas-external
  namespace: default
spec:
  ports:
    - port: 5001
      protocol: TCP
---
apiVersion: v1
kind: Endpoints
metadata:
  name: nas-external
  namespace: default
subsets:
  - addresses:
      - ip: 192.168.0.201
    ports:
      - port: 5001
```

**Synology Drive app fails silently on mobile**
The Synology Drive iOS app fails at the server connection screen with
a generic network error and never shows a login prompt. The NAS logs
show no connection attempt from the app at all — the failure is
client-side. Root cause: the app requires user home service to be
enabled AND a compatible DSM version. Even with homes enabled the app
did not work. Use **DS File** instead — it connects reliably on both
iOS and Android.

**Drive Server requires user home service**
Without user home service enabled, Drive Server logs:
`Failed to get share: homes, err=[0x1400]`
The mobile app fails immediately. Fix: Control Panel → User & Group →
Advanced → Enable user home service → Apply. The `homes` shared folder
is created automatically.

**NAS backend cert**
The NAS uses its own self-signed cert on port 5001. Traefik must use
`insecureSkipVerify: true` in the ServersTransport to accept it on the
backend connection. The wildcard cert (`*.kds-dev.com`) covers the
frontend — browsers see a valid cert.

---

## Notes

- Port 6690 is the Drive sync protocol port — used by desktop sync
  client, not relevant for mobile or web access
- Port 5001 is DSM HTTPS — all web and app access goes here
- `share.kds-dev.com` is the bookmark for family document storage
- `nas.kds-dev.com` is for NAS administration
- Both URLs use the wildcard `*.kds-dev.com` cert via Traefik