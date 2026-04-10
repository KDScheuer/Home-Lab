# NFS Subdir External Provisioner

## Install

```bash
cd ~/Home-Lab/helm/infra/nfs-subdir-external-provisioner

helm install nfs-subdir-external-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace nfs-provisioner \
  --create-namespace \
  --set nfs.server=192.168.0.201 \
  --set nfs.path=/volume1/networkShare/srv \
  --set storageClass.name=nfs \
  --set storageClass.defaultClass=true \
  --set storageClass.reclaimPolicy=Retain
```

Verify pod is running and storage class was created:

```bash
kubectl -n nfs-provisioner get pods
kubectl get storageclass
```

k3s ships with `local-path` as the default storage class. Remove that flag or
PVCs without an explicit class will bind to the wrong provisioner:

```bash
kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "false"}}}'
```

Verify `nfs` is the only default:

```bash
kubectl get storageclass
```

## Test

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

Should show `Bound` within a few seconds:

```bash
kubectl get pvc nfs-test
```

Confirm a subdirectory was created under `/volume1/networkShare/srv/` on the
Synology. Clean up:

```bash
kubectl delete pvc nfs-test
```

The directory on the NAS will remain after deletion — this is `Retain` policy
working correctly. Delete it manually from DSM if not needed.

---

## Notes

- NFS path: `/volume1/networkShare/srv` on `192.168.0.201`
- Reclaim policy is `Retain` — deleting a PVC never deletes data on the NAS
- Provisioner auto-creates subdirectories per PVC with generated names
- For apps with existing data use static PVs pointing at the existing path
  instead of letting the provisioner create a new empty directory
- Synology has root squash enabled — pods writing to provisioner-managed
  directories run as UID 1024 / GID 100 to match NAS file ownership