# Terraform

Terraform provisions all VMs by cloning the Rocky 9 cloud-init template (VM 9000). It requires a valid Proxmox API token and the template to exist before running.

---

## Provider

Uses [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox) `~> 0.73.0`. Requires Terraform `>= 1.5.0`.

State is stored locally in `terraform.tfstate` (gitignored).

---

## Prerequisites

- Proxmox cluster configured — Ansible `proxmox_config.yml` has been run
- Rocky 9 cloud-init template (VM 9000) exists on `vm-disks` — see [vm-template/rocky-template.md](../vm-template/rocky-template.md)
- Proxmox API token created for `root@pam` — see [docs/deploy-from-scratch.md](../docs/deploy-from-scratch.md#14-create-the-terraform-api-token)
- SSH key pair at `~/.ssh/id_ed25519` (or override with `ssh_private_key_path`)

---

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `proxmox_endpoint` | Proxmox API URL | — (required) |
| `proxmox_api_token` | `root@pam!terraform=<secret>` | — (required, sensitive) |
| `ssh_public_key` | SSH public key injected into VMs via cloud-init | — (required) |
| `ssh_private_key_path` | Private key for Proxmox SSH operations | `~/.ssh/id_ed25519` |
| `proxmox_node_map` | VM name → Proxmox node pinning | See below |
| `network_gateway` | Default gateway for all VMs | `192.168.50.1` |
| `network_dns` | DNS servers for all VMs | `["1.1.1.1", "8.8.8.8"]` |
| `network_domain` | Domain name for all VMs | `kds-dev.com` |
| `template_id` | Source template VM ID | `9000` |
| `storage_pool` | VM disk storage pool | `vm-disks` |
| `cloudinit_storage` | Storage pool for cloud-init drives | `vm-disks` |

### VM Pinning and IPs

| VM | Node | IP | Role |
|----|------|----|------|
| ts1 | node1 | 192.168.50.131 | Tailscale subnet router (Proxmox HA enabled) |
| ctrl1 | node1 | 192.168.50.111 | k3s control plane |
| ctrl2 | node2 | 192.168.50.112 | k3s control plane |
| ctrl3 | node3 | 192.168.50.113 | k3s control plane |
| work1 | node1 | 192.168.50.121 | k3s worker |
| work2 | node2 | 192.168.50.122 | k3s worker |
| work3 | node3 | 192.168.50.123 | k3s worker |

Each VM ID matches the last octet of its IP address (e.g., ctrl1 → VM ID 111).

---

## Usage

### Configure variables

Create `terraform.tfvars` (gitignored, never committed):

```hcl
proxmox_endpoint  = "https://192.168.50.101:8006"
proxmox_api_token = "root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
ssh_public_key    = "ssh-ed25519 AAAA...your-key"
```

### Run

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Destroy

```bash
terraform destroy
```

> Destroying VMs does not affect the template (VM 9000) or NFS application data under `/srv`.

---

## Files

| File | Purpose |
|------|---------|
| `provider.tf` | bpg/proxmox provider and SSH connection config |
| `versions.tf` | Provider version constraints and backend config |
| `variables.tf` | All input variable declarations |
| `terraform.tfvars` | Local variable values — gitignored |
| `control_plane.tf` | ctrl1, ctrl2, ctrl3 VM resources |
| `workers.tf` | work1, work2, work3 VM resources |
| `tailscale.tf` | ts1 VM resource (Proxmox HA enabled) |
| `outputs.tf` | VM IP address summary |

---

## Notes

- `terraform.tfvars` and `terraform.tfstate` are gitignored — they contain sensitive values and local state
- Control plane VMs have Proxmox HA **disabled** intentionally — k3s handles its own HA and Proxmox HA can interfere with etcd during node maintenance
- ts1 has Proxmox HA **enabled** — it must survive a Proxmox node failure because ts1 is the remote recovery path if k3s breaks
- The `lifecycle { ignore_changes = [disk, vga] }` block prevents Terraform from detecting Proxmox-side cloud-init drive changes after first apply
