# Homelab Deployment Order

Follow these docs in order for a full rebuild from scratch.

---

### 1. NAS Setup
Configure the Synology NAS — volume, NFS share, and subdirectories must be in place before Proxmox storage and k3s PVs can use them.

[NAS Setup](nas-setup.md)

---

### 2. WSL Setup
Get the local management environment ready — tools, SSH key, repo clone, and `.env` populated.

[WSL Setup](wsl-setup.md)

---

### 3. Infrastructure & Cluster Deployment
Provision Proxmox, deploy VMs with Terraform, and bring up the k3s cluster with Ansible.

[Infrastructure & Cluster Deployment](infra-and-cluster-deployment.md)

---

### 4. Tailscale Setup
Join `ts1` to the tailnet and approve the subnet route. Do this before deploying services so remote access is available.

[Tailscale Setup](tailscale-setup.md)

---

### 5. Service Deployment
Deploy applications into the cluster.

[Service Deployment](service-deployment.md) *(in progress)*