# Traefik

## Prerequisites

cert-manager must be installed and the wildcard cert issued before enabling
the TLS store in values.yml. Comment out the redirect and TLS store sections
until the cert exists.

In `values.yml`, comment out these sections initially:

```yaml
# ports:
#   web:
#     http:
#       redirections:
#         entryPoint:
#           to: websecure
#           scheme: https
#           permanent: true

# tlsStore:
#   default:
#     defaultCertificate:
#       secretName: wildcard-kds-dev-com-tls
```

## Install

```bash
cd ~/Home-Lab/helm/infra/traefik

helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  -f values.yml
```

Watch pods come up:

```bash
kubectl -n traefik get pods -w
```

Verify MetalLB assigned `192.168.50.120`:

```bash
kubectl -n traefik get svc
```

## Enable TLS and Redirect

Once the wildcard cert is issued (see cert-manager runbook), uncomment the
sections above in `values.yml` and upgrade:

```bash
helm upgrade traefik traefik/traefik \
  --namespace traefik \
  -f values.yml
```

Verify TLS is working — look for `HTTP/2`:

```bash
curl -I https://192.168.50.120 --insecure
```

Verify HTTP redirect is working — look for `308 Permanent Redirect`:

```bash
curl -I http://192.168.50.120
```

---

## Notes

- MetalLB IP: `192.168.50.120` — all `*.kds-dev.com` DNS rewrites point here
- 3 replicas, LoadBalancer type, annotated to use `homelab-pool`
- IngressRoutes in app namespaces use `tls: {}` — picks up default wildcard
  cert from TLS store automatically, no per-app secret reference needed
- Webhook 502 errors on first install are a k3s + Rocky 9 firewall issue —
  fixed by adding pod/service CIDRs to firewalld trusted zone on all nodes