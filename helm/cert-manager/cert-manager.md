Install 
```bash
helm install cert-manager cert-manager/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

Watch pods come up
> *Wait for all three to show 1/1 Running*
```bash
kubectl -n cert-manager get pods -w
```

Now create the Route53 secret:
```bash
kubectl create secret generic route53-credentials \
  --namespace cert-manager \
  --from-literal=secret-access-key=$AWS_SECRET_ACCESS_KEY
```

Verify it was created:
```bash
kubectl -n cert-manager get secret route53-credentials
```
Patch the webhook to Ignore temporarily
```bash
kubectl patch validatingwebhookconfiguration cert-manager-webhook \
  --type='json' \
  -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
```

Install
```bash
cd ~/Home-Lab/helm/cert-manager
envsubst < clusterissuer.yaml | kubectl apply -f -
```

Reset webhook to Fail
```bash
kubectl patch validatingwebhookconfiguration cert-manager-webhook \
  --type='json' \
  -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Fail"}]'
```

Verify
```bash
kubectl get clusterissuer letsencrypt-prod
```

Issue Cert
```bash
kubectl apply -f certificate.yml
```

Monitor Cert Issue
```bash
kubectl -n traefik get challenges
kubectl -n traefik describe challenge {NAME}
kubectl -n traefik get certificate
```

Verify Secret Contains Cert
```bash
kubectl -n traefik get secret wildcard-kds-dev-com-tls
```
