Comment Out TLS Store until TLS cert has been issued
```bash
# http:
#   redirections:
#     entryPoint:
#       to: websecure
#       scheme: https
#       permanent: true

# tlsStore:
#   default:
#     defaultCertificate:
#       secretName: wildcard-kds-dev-com-tls
```

Install
```bash
cd ~/Home-Lab/helm/infra/traefik

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

Once cert has been issued uncomment the lines from step one and run
```bash
cd ~/Home-Lab/helm/infra/traefik

helm upgrade traefik traefik/traefik \
  --namespace traefik \
  -f values.yml
```

Verify Traefik is Issuing the cert
> *Should See HTTP/2*
```bash
curl -I https://192.168.50.120 --insecure
```

Verify http redirect is working
> *Should See 308 Permanent Redirect*
```bash
curl -I http://192.168.50.120
```