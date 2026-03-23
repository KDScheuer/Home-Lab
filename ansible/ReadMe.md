# Ansible

Ansible manages Proxmox node configuration and all VM provisioning. All playbooks are idempotent and safe to re-run.

---

## Structure

```
ansible/
├── ansible.cfg
├── requirements.yml              # Community role dependencies
├── inventory/
│   ├── hosts.yml                 # Host inventory
│   └── group_vars/
│       ├── all/
│       │   ├── main.yml          # Non-secret shared variables
│       │   ├── secrets.yml       # k3s_token — gitignored, never committed
│       │   └── secrets.yml.example
│       ├── k3s_control.yml       # kube-vip VIP, k3s server config
│       └── k3s_workers.yml       # k3s agent config
├── playbooks/
│   ├── site.yml                  # Full VM provisioning in dependency order
│   ├── proxmox_config.yml        # Proxmox node configuration
│   ├── rocky_baseline.yml        # Standalone: baseline all VMs
│   ├── k3s_install.yml           # Standalone: deploy k3s cluster only
│   └── tailscale.yml             # Standalone: configure ts1 only
└── roles/
    ├── proxmox_base/             # Repos, NTP (chrony), SSH hardening, sudo
    ├── proxmox_storage/          # NFS storage mounts and content type config
    ├── proxmox_ha/               # HA group creation and policy
    ├── rocky_baseline/           # OS baseline for all Rocky VMs
    ├── k3s_control/              # control plane: firewall + kube-vip + xanmanning.k3s
    ├── k3s_worker/               # workers: firewall + xanmanning.k3s agent
    ├── kube_vip/                 # Drops kube-vip static manifest before k3s starts
    └── tailscale/                # Installs Tailscale daemon and enables routing
```

---

## Setup

### Install dependencies

```bash
ansible-galaxy install -r requirements.yml
```

This installs `xanmanning.k3s` — the community role that handles k3s installation and cluster bootstrapping.

### Configure secrets

```bash
cp inventory/group_vars/all/secrets.yml.example inventory/group_vars/all/secrets.yml
```

Generate a cluster token and set it as `k3s_token` in `secrets.yml`:

```bash
openssl rand -hex 32
```

`secrets.yml` is gitignored and never committed.

---

## Playbooks

### `proxmox_config.yml`

Configures all three Proxmox nodes. Run **once after cluster formation**, safe to re-run.

Applies: `proxmox_base` → `proxmox_storage` → `proxmox_ha`

```bash
ansible-playbook playbooks/proxmox_config.yml
```

### `site.yml`

Full VM provisioning in dependency order. Run after Terraform has provisioned all VMs and cloud-init has completed.

```bash
ansible-playbook playbooks/site.yml
```

| Step | Role | Hosts | Purpose |
|------|------|-------|---------|
| 1 | `rocky_baseline` | All VMs | Package updates, chrony NTP, hostname, SSH hardening, SELinux, firewalld |
| 2 | `tailscale` | ts1 | Install and enable Tailscale daemon |
| 3 | `k3s_control` | ctrl1/ctrl2/ctrl3 | kube-vip manifest + k3s server (embedded etcd HA) |
| 4 | `k3s_worker` | work1/work2/work3 | Join cluster as k3s agents |

### Standalone playbooks

| Playbook | Purpose |
|----------|---------|
| `rocky_baseline.yml` | Re-apply OS baseline to all VMs |
| `k3s_install.yml` | Re-deploy k3s cluster only (skips baseline) |
| `tailscale.yml` | Re-configure ts1 only |

---

## Roles

| Role | Applies to | Purpose |
|------|------------|---------|
| `proxmox_base` | Proxmox nodes | Removes enterprise repos, adds no-sub repo, NTP via chrony, SSH hardening |
| `proxmox_storage` | Proxmox nodes | Mounts NFS shares (`vm-disks`, `srv`), sets correct content types |
| `proxmox_ha` | Proxmox nodes | Creates HA groups with node affinity policies |
| `rocky_baseline` | All VMs | Package updates, chrony NTP, hostname, SSH hardening, SELinux enforcement, firewalld |
| `kube_vip` | ctrl1/ctrl2/ctrl3 | Places kube-vip static manifest in k3s auto-deploy directory |
| `k3s_control` | ctrl1/ctrl2/ctrl3 | Opens firewall ports, deploys kube-vip manifest, runs `xanmanning.k3s` (server) |
| `k3s_worker` | work1/work2/work3 | Opens firewall ports, runs `xanmanning.k3s` (agent) |
| `tailscale` | ts1 | Installs Tailscale, enables daemon, configures subnet routing |

---

## Inventory

| Group | Hosts | IPs |
|-------|-------|-----|
| `proxmox` | node1, node2, node3 | .101, .102, .103 |
| `k3s_control` | ctrl1, ctrl2, ctrl3 | .111, .112, .113 |
| `k3s_workers` | work1, work2, work3 | .121, .122, .123 |
| `tailscale` | ts1 | .131 |

All hosts use `ansible_user: ansible` with key-based SSH auth (no password).

---

## Running from WSL

The `ansible.cfg` sets the inventory path relative to the `ansible/` directory. Run playbooks from there:

```bash
cd /path/to/repo/ansible
ansible-playbook playbooks/site.yml
```

To specify the config explicitly from another directory:

```bash
ANSIBLE_CONFIG=/path/to/repo/ansible/ansible.cfg ansible-playbook playbooks/proxmox_config.yml
```
