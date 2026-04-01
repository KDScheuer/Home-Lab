# cert-manager

## Prerequisites

AWS credentials must be loaded in the shell before running. The `.env` file
contains `AWS_SECRET_ACCESS_KEY` and `AWS_ACCESS_KEY_ID`. Source it first:

```bash
source ~/Home-Lab/.env
```

## Install

```bash
helm install cert-manager cert-manager/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

Wait for all three pods to show `1/1 Running` — cert-manager, cainjector,
and webhook:

```bash
kubectl -n cert-manager get pods -w
```

## Create Route53 Secret

```bash
kubectl create secret generic route53-credentials \
  --namespace cert-manager \
  --from-literal=secret-access-key=$AWS_SECRET_ACCESS_KEY
```

Verify:

```bash
kubectl -n cert-manager get secret route53-credentials
```

## Apply ClusterIssuer

Same webhook 502 issue as MetalLB on k3s + Rocky 9. Disable validation
temporarily:

```bash
kubectl patch validatingwebhookconfiguration cert-manager-webhook \
  --type='json' \
  -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
```

Apply the ClusterIssuer — `envsubst` substitutes `$CERT_EMAIL`,
`$ROUTE53_ZONE_ID`, and `$AWS_ACCESS_KEY_ID` from the loaded `.env`:

```bash
cd ~/Home-Lab/helm/infra/cert-manager
envsubst < clusterissuer.yml | kubectl apply -f -
```

Restore webhook validation:

```bash
kubectl patch validatingwebhookconfiguration cert-manager-webhook \
  --type='json' \
  -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Fail"}]'
```

Verify ClusterIssuer is ready:

```bash
kubectl get clusterissuer letsencrypt-prod
```

Should show `READY: True`. If `False` check logs:

```bash
kubectl -n cert-manager logs -l app=cert-manager | tail -20
```

## Issue Wildcard Certificate

```bash
kubectl apply -f certificate.yml
```

Monitor the challenge — DNS-01 via Route53 takes 1-2 minutes:

```bash
kubectl -n traefik get challenges -w
```

If a challenge stays pending describe it to see the error:

```bash
kubectl -n traefik describe challenge <NAME>
```

Watch for cert to go `READY: True`:

```bash
kubectl -n traefik get certificate -w
```

Verify the TLS secret was created in the traefik namespace:

```bash
kubectl -n traefik get secret wildcard-kds-dev-com-tls
```

---

## Notes

- ClusterIssuer uses DNS-01 via Route53 — requires outbound internet from
  cert-manager pod, which requires flannel overlay routing to be working
- Cert is stored as `wildcard-kds-dev-com-tls` in the `traefik` namespace
- Covers `*.kds-dev.com` and `kds-dev.com`
- All app IngressRoutes use `tls: {}` — they reference the default TLS store
  in Traefik, not the secret directly. The secret stays in the traefik namespace
- If a `_acme-challenge.kds-dev.com` TXT record already exists in Route53 from
  a previous certbot run, the challenge will fail with `InvalidChangeBatch`.
  Delete the existing TXT record in Route53 console first, then delete and
  reapply the certificate manifest
- `.env` variables needed: `AWS_SECRET_ACCESS_KEY`, `AWS_ACCESS_KEY_ID`,
  `CERT_EMAIL`, `ROUTE53_ZONE_ID`