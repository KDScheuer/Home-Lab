# Deploy From Scratch

A complete bootstrap guide for standing up this lab from bare hardware.
Also serves as a DR recovery runbook — see the [DR Notes](#dr-notes) section at the bottom.

**Estimated time:** 2–3 hours for a full deploy from bare metal.

---

## Prerequisites

- 3 × physical nodes (ThinkCentre M710q) with Proxmox ISO on USB
- Synology NAS configured with two NFS exports: `/volume1/vm-disks` and `/volume1/srv`
- Management machine running WSL2 — see [wsl-setup.md](wsl-setup.md)
- Tailscale account with admin access to the tailnet
- This repository cloned locally

---

## Phase 1 — Proxmox Cluster

### 1.1 Install Proxmox on each node

Enable virtualization (VT-x / AMD-V) in BIOS before installing.

Manually install Proxmox VE on each physical node and assign static IPs during setup:

| Node  | IP             |
|-------|----------------|
| node1 | 192.168.50.101 |
| node2 | 192.168.50.102 |
| node3 | 192.168.50.103 |

### 1.2 Form the cluster

On **node1**:
```bash
pvecm create homelab
```

On **node2** and **node3**:
```bash
pvecm add 192.168.50.101
```

Verify all three nodes appear in the Proxmox web UI under Datacenter → Cluster.

### 1.3 Bootstrap each node for Ansible

Run the following on **each node** as root. The enterprise repos must be swapped out before `apt update` will work without a subscription.

```bash
# Disable enterprise repos
echo '' > /etc/apt/sources.list.d/pve-enterprise.sources
echo '' > /etc/apt/sources.list.d/ceph.sources

# Add no-subscription repo
echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" > /etc/apt/sources.list.d/pve-nosub.list

# Install sudo (not included in Proxmox by default)
apt update && apt install -y sudo
```

Create the Ansible user and authorize your SSH public key:

```bash
useradd -m -s /bin/bash ansible
echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible

mkdir -p /home/ansible/.ssh
chmod 700 /home/ansible/.ssh
touch /home/ansible/.ssh/authorized_keys
chmod 600 /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible/.ssh

# Paste the contents of ~/.ssh/ansible.pub from your management machine
echo "YOUR_ANSIBLE_PUBLIC_KEY" >> /home/ansible/.ssh/authorized_keys
```

### 1.4 Create the Terraform API token

In the Proxmox web UI at `https://192.168.50.101:8006`:

1. Datacenter → Permissions → API Tokens → **Add**
2. User: `root@pam`, Token ID: `terraform`, uncheck **Privilege Separation**
3. Click **Add** and copy the secret immediately — it is shown only once

You will end up with credentials in this format:
```
root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

## Phase 2 — Ansible: Proxmox Configuration

Run the Proxmox configuration playbook from WSL. This applies NTP (chrony), SSH hardening, NFS storage mounts, and HA group configuration across all three nodes.

```bash
cd /path/to/repo/ansible
ansible-playbook playbooks/proxmox_config.yml
```

See [../ansible/README.md](../ansible/README.md) for full playbook and role reference.

---

## Phase 3 — VM Template

Build the Rocky 9 cloud-init template on node1. This is a manual one-time step — the template lives on shared NFS storage and is accessible from all nodes once created.

See [../vm-template/rocky-template.md](../vm-template/rocky-template.md) for the full runbook.

---

## Phase 4 — Terraform: Provision VMs

### 4.1 Configure variables

Set the required variables in `terraform/terraform.tfvars`:

```hcl
proxmox_endpoint  = "https://192.168.50.101:8006"
proxmox_api_token = "root@pam!terraform=YOUR_TOKEN_SECRET"
ssh_public_key    = "ssh-ed25519 AAAA...your-key"
```

### 4.2 Run Terraform

```bash
cd /path/to/repo/terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

This provisions seven VMs: `ctrl1`, `ctrl2`, `ctrl3` (k3s control plane), `work1`, `work2`, `work3` (k3s workers), and `ts1` (Tailscale subnet router).

See [../terraform/README.md](../terraform/README.md) for the full variable reference.

---

## Phase 5 — Ansible: VM Baseline + k3s

### 5.1 Set the k3s cluster token

```bash
cp ansible/inventory/group_vars/all/secrets.yml.example \
   ansible/inventory/group_vars/all/secrets.yml
```

Generate a token and set it as the value of `k3s_token` in `secrets.yml`:

```bash
openssl rand -hex 32
```

### 5.2 Run the full site playbook

```bash
cd /path/to/repo/ansible
ansible-playbook playbooks/site.yml
```

This runs in dependency order:

| Step | Role | Hosts | Purpose |
|------|------|-------|---------|
| 1 | `rocky_baseline` | All VMs | Package updates, chrony NTP, hostname, SSH hardening, SELinux, firewalld |
| 2 | `tailscale` | ts1 | Install Tailscale daemon and enable routing |
| 3 | `k3s_control` | ctrl1/ctrl2/ctrl3 | Deploy kube-vip manifest + k3s server (embedded etcd HA) |
| 4 | `k3s_worker` | work1/work2/work3 | Join cluster as k3s agents |

### 5.3 Join ts1 to the Tailscale tailnet

This step is intentionally manual — device approval (Taillock) is enabled on the tailnet and cannot be automated without undermining its purpose.

See [runbook-tailscale-join.md](runbook-tailscale-join.md) for the full runbook.

---

## Phase 6 — Verify the Cluster

Copy the kubeconfig from ctrl1 and point it at the kube-vip VIP:

```bash
scp ansible@192.168.50.111:/etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i 's/127.0.0.1/192.168.50.110/g' ~/.kube/config
chmod 600 ~/.kube/config
```

Verify all six nodes are `Ready`:

```bash
kubectl get nodes -o wide
```

Expected output:
```
NAME    STATUS   ROLES                       AGE   VERSION
ctrl1   Ready    control-plane,etcd,master   ...   v1.x.x
ctrl2   Ready    control-plane,etcd,master   ...   v1.x.x
ctrl3   Ready    control-plane,etcd,master   ...   v1.x.x
work1   Ready    <none>                      ...   v1.x.x
work2   Ready    <none>                      ...   v1.x.x
work3   Ready    <none>                      ...   v1.x.x
```

---

## DR Notes

| Scenario | Recovery starting point |
|----------|------------------------|
| Single Proxmox node failure | Proxmox HA auto-restarts VMs on surviving nodes. ts1 restarts automatically. k3s tolerates one node loss without quorum loss. No action needed. |
| Full cluster destroyed, Proxmox nodes intact | Start from Phase 5. |
| VMs lost, Proxmox nodes intact, template intact | Start from Phase 4. |
| VMs lost, Proxmox nodes intact, template lost | Start from Phase 3. |
| Everything lost | Start from Phase 1. |
| etcd corrupted | Restore from a Proxmox VM snapshot taken before the corruption event. |

**NFS is the single most important dependency.** If the NAS is healthy, the VM disk template, cloud-init snippet, and all application data survive a full Proxmox rebuild. If the NAS is lost, only VMs need to be reprovisioned — application data must be restored from NAS backups.

