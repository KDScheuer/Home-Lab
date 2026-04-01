# Helm

Helm charts and manifests for the kds-dev.com homelab cluster.

## Structure

```
helm/
├── infra/          platform layer — must be deployed before apps
│   ├── metallb/
│   ├── traefik/
│   ├── cert-manager/
│   └── nfs-subdir-external-provisioner/
└── apps/           workloads
    ├── vaultwarden/
    ├── adguard/
    ├── jellyfin/
    └── ...
```

## Deploy Order

Infrastructure must come up in this order before any apps are deployed:

1. MetalLB
2. Traefik
3. cert-manager
4. NFS provisioner

## Notes

- All app IngressRoutes use `tls: {}` — wildcard cert is handled by Traefik's
  default TLS store, no per-app secret reference needed
- Apps with existing data use static PVs pointing at NAS paths directly rather
  than the NFS provisioner
- Secrets are never committed — recreate from `.env` or Vaultwarden on rebuild