# Deploying Infrastructure and K3s Cluster

> **Before you begin:** Copy `.env.example` to `.env` at the repo root. You will fill in values as you work through the steps below — the API token isn't available until step 2, and the SSH key until step 1. Source `.env` before running any Terraform or Ansible commands.

---

## 1. Install Proxmox on All 3 Servers and Form a Cluster

After installing Proxmox and joining all three nodes into a cluster via the web UI, run the following on **each host** to prepare it for Ansible management.

> Once you have your SSH key pair, set `TF_VAR_ssh_public_key` and `TF_VAR_ssh_private_key_path` in `.env`.

```bash
# Disable enterprise repos
echo '' > /etc/apt/sources.list.d/pve-enterprise.sources
echo '' > /etc/apt/sources.list.d/ceph.sources

# Add the no-subscription repo
echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" > /etc/apt/sources.list.d/pve-nosub.list

# Install sudo (not included in Proxmox by default)
apt update && apt install -y sudo

# Create the Ansible user
useradd -m -s /bin/bash ansible
echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible

# Authorize the Ansible SSH public key
mkdir -p /home/ansible/.ssh && chmod 700 /home/ansible/.ssh
echo "YOUR_ANSIBLE_PUBLIC_KEY" >> /home/ansible/.ssh/authorized_keys
chmod 600 /home/ansible/.ssh/authorized_keys && chown -R ansible:ansible /home/ansible/.ssh
```

---

## 2. Create a Proxmox API Token for Terraform

1. Navigate to **Datacenter → Permissions → API Tokens → Add**
2. User: `root@pam`, Token ID: `terraform`, uncheck **Privilege Separation**
3. Click **Add**, copy the secret, and update `TF_VAR_proxmox_api_token` in `.env`

---

## 3. Configure Proxmox Hosts with Ansible

Applies no-subscription repos, NTP, storage mounts, and HA grouping across all three nodes.

```bash
cd /mnt/c/Users/kdsch/OneDrive/Desktop/Home-Lab/ansible
ansible-playbook playbooks/proxmox_config.yml
```

---

## 4. Create the Rocky 9 Cloud-Init Template

This is a manual one-time step. The template is built on `node1` and stored on shared NFS storage, making it accessible from all nodes.

See [../vm-template/rocky-template.md](../vm-template/rocky-template.md) for the full runbook.

---

## 5. Provision VMs with Terraform

Creates all VMs (control plane, workers, Tailscale node) via the Proxmox provider.

```bash
cd /mnt/c/Users/kdsch/OneDrive/Desktop/Home-Lab/terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

---

## 6. Configure VMs and Deploy the Cluster with Ansible

A single playbook run handles everything in dependency order:
1. **Rocky baseline** — updates, chrony, hostname, SSH hardening, firewalld (all VMs)
2. **Tailscale** — installs and configures the subnet router on `ts1` *(join is manual — see step 7)*
3. **k3s control plane** — bootstraps the HA control plane across `ctrl1`, `ctrl2`, `ctrl3`
4. **k3s workers** — joins `work1`, `work2`, `work3` to the cluster

```bash
cd /mnt/c/Users/kdsch/OneDrive/Desktop/Home-Lab/ansible
ansible-playbook playbooks/site.yml
```

---

## 7. Join Tailscale Manually

Tailscale authentication is intentionally not automated. After `site.yml` completes, SSH into `ts1` and join the tailnet manually.

See [runbook-tailscale-join.md](runbook-tailscale-join.md) for the full steps.

---

## 8. Retrieve the Kubeconfig

Copy the kubeconfig from `ctrl1` and point it at the kube-vip VIP so it remains valid regardless of which control plane node is active:

```bash
mkdir -p ~/.kube
scp -i ~/.ssh/ansible ansible@192.168.50.111:/etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i 's/127.0.0.1/192.168.50.110/g' ~/.kube/config
chmod 600 ~/.kube/config
kubectl get nodes
```
