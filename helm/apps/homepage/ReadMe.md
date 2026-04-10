# Homepage

## Overview

Self-hosted dashboard at `https://home.kds-dev.com`. Four column layout
with Infrastructure, Apps, External, and Business sections. Google search
with autocomplete, local background image, glassmorphism card style.

---

## Deploy

```bash
cd ~/Home-Lab/helm/apps/homepage
kubectl apply -f namespace.yml
kubectl apply -f pv.yml
kubectl apply -f deployment.yml
kubectl apply -f ingress.yml
```

Watch pod come up:

```bash
kubectl -n homepage get pods -w
```

Add DNS rewrite in AdGuard: `home.kds-dev.com → 192.168.0.120`

---

## NAS Directory Structure

All config and assets live on the NAS. Create these directories before
deploying:

```bash
mkdir -p /mnt/synology/srv/homepage/config
mkdir -p /mnt/synology/srv/homepage/icons
```

Copy config files from repo to NAS:

```bash
cp ~/Home-Lab/helm/apps/homepage/config/* \
  /mnt/synology/srv/homepage/config/
```

Copy background image to config directory:

```bash
cp /path/to/background.jpg \
  /mnt/synology/srv/homepage/config/background.jpg
```

Copy custom icons to icons directory:

```bash
cp ~/Home-Lab/helm/apps/homepage/icons/* \
  /mnt/synology/srv/homepage/icons/
```

---

## Config Files

All config lives at `/volume1/networkShare/srv/homepage/config/` on the NAS.

```
config/
├── settings.yaml    ← theme, layout, background, search config
├── services.yaml    ← all service tiles and sections
├── widgets.yaml     ← top bar widgets (datetime, search)
├── bookmarks.yaml   ← empty, services.yaml handles everything
├── background.jpg   ← local background image
└── custom.css       ← custom styling overrides
```

Custom icons live at `/volume1/networkShare/srv/homepage/icons/`.

---

## Updating Config

Homepage hot-reloads YAML config files — edit on the NAS and refresh
the browser. No pod restart needed for service, settings, or widget
changes.

**Exception — images and icons require a full pod delete and recreate:**

```bash
kubectl -n homepage delete pod -l app=homepage
kubectl -n homepage get pods -w
```

This is a Next.js static site limitation — images are baked into the
static build at startup, not served dynamically.

---

## Verify

```bash
curl -I https://home.kds-dev.com
kubectl -n homepage logs -l app=homepage | tail -10
```

---

## Gotchas

**Host validation failed**
Homepage rejects requests from unrecognized hostnames. Fix is the
`HOMEPAGE_ALLOWED_HOSTS` environment variable in the deployment — not
the `allowedHosts` key in settings.yaml. Both must be set:

In `deployment.yml`:
```yaml
env:
  - name: HOMEPAGE_ALLOWED_HOSTS
    value: "home.kds-dev.com"
```

**Background image not showing**
Homepage is a Next.js static site. Images must exist in
`/app/public/images/` at container startup — they are baked into the
static build, not served dynamically. Simply copying a file to the NAS
and restarting the pod is not enough. You must fully delete the pod so
it recreates and Next.js picks up the new image during build:

```bash
kubectl -n homepage delete pod -l app=homepage
```

A `rollout restart` does not work for this — it must be a full pod
delete.

**bookmarks.yaml content mixed with settings.yaml**
If bookmarks returns a 500 error check that `bookmarks.yaml` actually
contains bookmarks config and not the contents of another file. Files
can get mixed up when copying. The bookmarks file should be empty or
contain only bookmark entries — not layout or background config.

**Wrong file extension for custom icons**
The filename in `services.yaml` must match exactly including extension.
If you upload `momnt.jpg` but reference `momnt.png` in the yaml the
icon will 404. Check extensions carefully.

**Custom icons use /icons/ prefix**
Icons uploaded to your icons directory must be referenced with the
`/icons/` prefix in services.yaml to avoid Homepage trying to fetch
them from the CDN instead:

```yaml
icon: /icons/wgu.png      # local custom icon
icon: jellyfin.png        # built-in CDN icon, no prefix needed
```

**si- icons don't work**
Simple Icons (`si-house`, `si-creditcard` etc) are not supported in
this version of Homepage. Use `mdi-` prefixed Material Design icons
instead:

```yaml
icon: mdi-home
icon: mdi-credit-card
icon: mdi-tree
```

**Settings changes not applying**
If settings.yaml changes aren't taking effect check that the file on
the NAS has the correct content and isn't accidentally containing
another file's config. Verify with:

```bash
kubectl -n homepage exec deployment/homepage -- cat /app/config/settings.yaml
```

**quicklaunch vs search widget**
`quicklaunch` in settings.yaml and the `search` widget in widgets.yaml
are two separate features. The search bar on the dashboard is the
widget. `quicklaunch` is a keyboard shortcut overlay. Both need to be
configured for full search functionality with suggestions.

---

## Icon Sources

**Built-in CDN icons** — reference by name only, no prefix:
```yaml
icon: jellyfin.png
icon: immich.png
icon: adguard-home.png
icon: grafana.png
icon: proxmox.png
icon: vaultwarden.png
```

Browse available icons at:
`https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/<name>.png`

**Custom icons** — drop in `/volume1/networkShare/srv/homepage/icons/`
and reference with `/icons/` prefix:
```yaml
icon: /icons/wgu.png
icon: /icons/fm.png
icon: /icons/git.png
```

After adding new icons delete and recreate the pod.

---

## Notes

- Config is in Git at `helm/apps/homepage/config/` — source of truth
- NAS config directory is the live version the pod reads
- Keep both in sync when making changes
- Background image is not in Git (binary file) — keep a copy somewhere
  safe and re-upload to NAS on rebuild
- Single replica, Recreate strategy
- IngressRoute uses `tls: {}` for wildcard cert via Traefik default TLS store