Install
``` bash
helm install metallb metallb/metallb \
  --namespace metallb-system \
  --create-namespace
```
Wait for pods to be ready
```bash
kubectl -n metallb-system get pods -w
```

Temporaly Disable Validation
```bash
helm upgrade metallb metallb/metallb \
  --namespace metallb-system \
  --set crds.validationFailurePolicy=Ignore
```

Apply
``` bash
cd ~/Home-Lab/helm/infra/metallb
kubectl apply -f ipaddresspool.yml
```

Readd Validation
```bash
helm upgrade metallb metallb/metallb \
  --namespace metallb-system \
  --set crds.validationFailurePolicy=Fail \
  --reuse-values

kubectl get validatingwebhookconfiguration metallb-webhook-configuration \
  -o jsonpath='{.webhooks[*].failurePolicy}'
```

Verify
```bash
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system
```

Both should show your resources with no errors.
```bash
kubectl -n metallb-system get pods
kubectl get ipaddresspool -n metallb-system
```