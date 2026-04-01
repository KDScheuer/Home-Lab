# MetalLB

## Install

```bash
helm install metallb metallb/metallb \
  --namespace metallb-system \
  --create-namespace
```

Wait for all pods Running — controller (1/1) and 6 speakers (4/4, one per node):

```bash
kubectl -n metallb-system get pods -w
```

## Apply IP Pool

The MetalLB webhook blocks resource creation until the controller is fully ready.
On k3s + Rocky 9 the webhook returns 502 due to firewall/routing — disable
validation temporarily before applying:

```bash
helm upgrade metallb metallb/metallb \
  --namespace metallb-system \
  --set crds.validationFailurePolicy=Ignore
```

Apply the IP pool:

```bash
cd ~/Home-Lab/helm/infra/metallb
kubectl apply -f ipaddresspool.yml
```

Restore validation:

```bash
helm upgrade metallb metallb/metallb \
  --namespace metallb-system \
  --set crds.validationFailurePolicy=Fail \
  --reuse-values
```

Verify validation is restored — should print `Fail` six times:

```bash
kubectl get validatingwebhookconfiguration metallb-webhook-configuration \
  -o jsonpath='{.webhooks[*].failurePolicy}'
```

## Verify

```bash
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system
kubectl -n metallb-system get pods
```

---

## Notes

- IP pool: `192.168.50.120-192.168.50.129`, L2 mode
- Assigned IPs: `.120` Traefik, `.128` Jellyfin direct, `.129` AdGuard DNS
- 6 speaker pods — one per node (3 control plane + 3 workers) — this is correct
- The webhook 502 issue is caused by the API server being unable to reach webhook
  pods across the flannel overlay — root cause is firewalld not having pod/service
  CIDRs in the trusted zone. Fixed in the k3s_control and k3s_worker Ansible
  roles. The Ignore workaround is only needed on first install before those
  firewall rules are applied
- If webhook 502 occurs when modifying the IP pool later, repeat the
  Ignore → apply → Fail upgrade sequence