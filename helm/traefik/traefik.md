Install
```bash
cd ~/Home-Lab/helm/traefik

helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  -f values.yml
```

Watch the pods come up
```bash
kubectl -n traefik get pods -w
```

Once Running check the service got a MetalLB IP
> *You're looking for 192.168.50.120 in the EXTERNAL-IP column*
```bash
kubectl -n traefik get svc
```