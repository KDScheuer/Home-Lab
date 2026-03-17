# Ansible

Automated configuration management for all homelab nodes. Every node receives a common baseline via the `standard` role. Nodes that are part of the k3s cluster receive that baseline plus k3s-specific configuration via the `k3s` role, layered on top.

---

## How it works

`site.yml` is the single entry point. It runs two plays in sequence:

1. **Standard play** — targets `all` hosts. Applies the `standard` role: packages, time sync, hostname, security hardening, user accounts, NFS mount, and firewall rules.
2. **k3s play** — targets `k3s_nodes` only. Applies the `k3s` role on top of the baseline already configured by the first play.

Ansible is invoked automatically by the provisioning server (`http-server.py`) when a node calls back after its kickstart install completes. It can also be run manually at any time — all tasks are idempotent.

---

## Running the playbook

Run the full site against all hosts:
```bash
ansible-playbook site.yml
```

Target a single host:
```bash
ansible-playbook site.yml --limit <hostname>
```

> Ansible connects as the `ansible` user using the key at `~/.ssh/ansible`. Both are set in `ansible.cfg` and require no flags at runtime.

---

## Configuration

### `ansible.cfg`

| Setting | Value | Purpose |
|---|---|---|
| `inventory` | `inventory/hosts.yml` | Default inventory, no `-i` flag needed |
| `remote_user` | `ansible` | Dedicated service account created by the kickstart install |
| `private_key_file` | `~/.ssh/ansible` | Key injected into nodes at provision time |

### `requirements.yml`

Two Galaxy collections are required. Install them with:
```bash
ansible-galaxy collection install -r requirements.yml --upgrade
```

| Collection | Used for |
|---|---|
| `ansible.posix` | `authorized_key`, `firewalld`, `mount`, `selinux` modules |
| `community.general` | `timezone` module |

---

## Inventory

### `inventory/hosts.yml`

Defines all managed hosts and their IPs. New nodes are registered here automatically by the provisioning server when a node calls back after install. The file can also be edited manually.

```
all:
  children:
    k3s_nodes:       ← hosts in this group get both the standard and k3s roles
      hosts:
        homenode01:
        homenode02:
        homenode03:
```

### `inventory/group_vars/all.yml`

Variables applied to every host regardless of role. Defines:

- `ansible_become`, `ansible_become_method`, `ansible_python_interpreter` — connection defaults
- `nfs_server` / `nfs_share` — Synology NAS mount details
- `lab_users` — list of user accounts to create and SSH keys to deploy on every node. Currently contains `home-user`, whose public key is read from the provisioning server at `~/.ssh/home-user.pub`

### `inventory/group_vars/k3s_nodes.yml`

Variables applied only to k3s cluster nodes. Currently empty — will be populated as the k3s role is built out.

---

## Roles

### `standard`

Applied to every node. Tasks run in this order:

| Area | What it does |
|---|---|
| **Packages** | Installs `nfs-utils` and `chrony` |
| **Time** | Sets timezone to `America/Boise`, deploys `chrony.conf` from template, ensures `chronyd` is running |
| **Hostname** | Sets the hostname to match `inventory_hostname` |
| **Security** | Ensures SELinux is `enforcing`, disables root SSH login |
| **Users** | Creates accounts defined in `lab_users`, deploys their SSH public keys |
| **NFS** | Creates `/mnt/synology` and mounts the Synology NAS share |
| **Firewall** | Opens ports defined in `firewall_ports` (default: `22/tcp`, `9100/tcp` for Prometheus node exporter) |

Default variables are defined in `roles/standard/defaults/main.yml` and can be overridden per host or group in `group_vars`.

**Handlers** — `sshd` and `chronyd` are restarted only when their respective config tasks report a change, preventing unnecessary service bounces.

---

### `k3s`

*Placeholder — not yet implemented.*

Will handle k3s cluster bootstrap and node configuration for all hosts in the `k3s_nodes` group. The `standard` role always runs first, so by the time this role executes the node already has its baseline config, users, NFS mount, and firewall rules in place.

---

## File structure

```
ansible/
├── ansible.cfg                        # Connection defaults
├── requirements.yml                   # Galaxy collection dependencies
├── site.yml                           # Entry point — runs all plays
├── inventory/
│   ├── hosts.yml                      # Host definitions and IPs
│   └── group_vars/
│       ├── all.yml                    # Variables for every host
│       └── k3s_nodes.yml              # Variables for k3s cluster nodes only
└── roles/
    ├── standard/
    │   ├── defaults/main.yml          # Default variable values
    │   ├── tasks/main.yml             # Baseline configuration tasks
    │   ├── handlers/main.yml          # sshd and chronyd restart handlers
    │   └── templates/chrony.conf.j2   # NTP config template
    └── k3s/
        ├── tasks/main.yml             # k3s configuration tasks (placeholder)
        └── handlers/main.yml          # k3s service handlers (placeholder)
```