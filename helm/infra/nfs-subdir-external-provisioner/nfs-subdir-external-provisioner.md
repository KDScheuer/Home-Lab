Install
```bash
helm install nfs-subdir-external-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace nfs-provisioner \
  --create-namespace \
  --set nfs.server=192.168.50.201 \
  --set nfs.path=/volume1/networkShare/srv \
  --set storageClass.name=nfs \
  --set storageClass.defaultClass=true \
  --set storageClass.reclaimPolicy=Retain
```

Check the provisioner pod is running and the storage class was created:
```bash
kubectl -n nfs-provisioner get pods
kubectl get storageclass
```

Two default storage classes will cause issues — Kubernetes gets confused when PVCs don't specify a class. Remove the default flag from local-path:
```bash
kubectl patch storageclass local-path -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "false"}}}'
```

Verify:
> *Should show nfs as the only default.*
```bash
kubectl get storageclass
```

Then do a quick test to confirm the provisioner actually works end to end:
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-test
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs
  resources:
    requests:
      storage: 1Mi
EOF
```

Check it bound:
> *Should show Bound within a few seconds. If it does check your Synology — you should see a new subdirectory created under /volume1/networkShare/srv/. That confirms the full chain is working: Kubernetes PVC → NFS provisioner → Synology NAS.*
```bash
kubectl get pvc nfs-test
```

Clean up after:
```bash
kubectl delete pvc nfs-test
```