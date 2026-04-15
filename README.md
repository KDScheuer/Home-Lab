# The Home Lab

### Virtualized locally hosted HA k3s cluster with NFS-backed storage

![k3s](https://img.shields.io/badge/k3s-v1.34-FFC61C?logo=k3s&logoColor=black)
![Proxmox](https://img.shields.io/badge/proxmox-9.1-E57000?logo=proxmox&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-provisioned-7B42BC?logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/ansible-managed-EE0000?logo=ansible&logoColor=white)
![Helm](https://img.shields.io/badge/helm-deployed-0F1689?logo=helm&logoColor=white)

![Homelab Picture](docs/assets/homelab.png)

---

- [Infrastructure and Network](#infrastructure-and-network)
- [Services](#services)
- [Home Lab Provisioning](#home-lab-provisioning)
- [Monitoring / Alerting](#monitoring--alerting)
- [Backup Process](#backup-process)
- [Design Decisions](#design-decisions)
- [Network Ranges](#network-ranges)
- [Hardware](#hardware)

---

## Infrastructure and Network
3 Node Proxmox Cluster Running 3 K3s Control Nodes, 3 K3s Worker Nodes, and 1 Tailscale Rocky VM. All Storage is backed with the Synology NAS via NFS mounts. Control plane consists of MetalLB, Traefik, cert-manager, and NFS provisioner.

[Hardware Specs](#hardware) | [Network Tables](#networks)

![Network Diagram](docs/assets/network.png)

---

## Services

Clients are directed to MetalLB via DNS provided by the router during DHCP. MetalLB has 3 VIP's assigned, .120 for application traffic using 443 or 80, .129 for DNS traffic using 53, and 128 for jellyfin traffic on port 8096 (required as our tv does not like being reverse proxied). Traefik is in place to reverse proxy to the service IP's as well as provide TLS termination. 

| Service        | Subdomain               | Purpose                  |
|----------------|-------------------------|--------------------------|
| AdGuard Home   | adguard.kds-dev.com     | DNS + ad blocking        |
| Vaultwarden    | vaultwarden.kds-dev.com | Password manager         |
| Jellyfin       | jellyfin.kds-dev.com    | Media server             |
| Immich         | immich.kds-dev.com      | Photo management         |
| Synology Drive | drive.kds-dev.com       | Family file storage      |
| Homepage       | home.kds-dev.com        | Self-hosted dashboard    |
| Mealie         | mealie.kds-dev.com      | Recipe and meal planning |

![Services Diagram](docs/assets/services.png)

---

## Home Lab Provisioning
NAS is manually configured following [NAS Config](/docs/nas-setup.md)

Proxmox is manually installed on each physical server and API Key generated. 

Everything else is infrastructure as code and deployed via terraform, ansible, and helm.

---

[Terraform](/terraform/)

  - Deploys 3 K3s Control Plane VM's
  - Deploys 3 K3s Worker VM's
  - Deploys 1 Tailscale VM
---

[Ansible](/ansible/)

  - Finishes Proxmox Configurations *(VM HA Rules, Storage, SSH Key Auth, etc.)*
  - Baseline Rocky Config *(Time, Hostname, Disabled Password Auth, SSH Key Auth, etc.)*
  - Creates & Configures K3s Cluster *(Creates Kube VIP, Firewall Rules, etcd, etc.)*
  - Configures Tailscale VM *(Install required packages, etc)*
---

[Helm](/helm/)
  - Deploys Infrastructure services MetalLB, Traefik, NFS Provisioner, Cert Manager
  - Issues TLS Certificate
  - Deploys Applications onto K3s Cluster

---

## Monitoring / Alerting
> Grafana/Prometheus stack deployment in progress 

---

## Backup Process
Backups are designed to be as simple as possible and are conducted according to the table below. 

More information regarding backups [Backup Strategy](/backups/ReadMe.md) 

| Backup      | Type     | Frequency                 | Retention         | Notes                                                   |
|-------------|----------|---------------------------|-------------------|---------------------------------------------------------|
| Application | On-Site  | Thursday (1–5am)          | 35 Days           | Service scaled to 0 for atomic operations               |
| Application | Off-Site | 1st Saturday of Month     | 180 Days          | Latest on-site backup copied to AWS S3 Glacier          |
| Application | Offline  | Quarterly                 | 2 Recovery Points | Copied to external SSD                                  |
| Secrets     | On-Site  | Hourly (change-triggered) | 5 Recovery Points | Only copies if hash of .env has changed                 |
| Secrets     | Off-Site | Sunday (1am)              | 5 AWS Versions    | Only copies if hash of .env has changed                 |
| Secrets     | Offline  | Quarterly                 | 5 Recovery Points | Copied to external SSD                                  |
| SSH Keys    | On-Site  | Manual                    | 2 Recovery Points | Copied to NAS manually                                  |
| SSH Keys    | Off-Site | Manual                    | 2 Recovery Points | Stored in AWS Secrets Manager                           |
| SSH Keys    | Offline  | Quarterly                 | 2 Recovery Points | Copied to external SSD                                  |

---

## Design Decisions

| Choice                   | Reason                                                                                                                                             |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| Dedicated Tailscale VM   | Allows for DR Access, Maintains HA via Proxmox, and is persistent to stay in Tailscale's free tier                                                 |
| K3s via Proxmox          | Allows for snapshots, easy provisioning / reprovisioning, allows for 3 control plane and 3 worker VM's                                             |
| Flat Networking          | A single /24 is in use due to my home router not supporting VLAN's for true separation of concerns                                                 |
| K3s Networking Isolated  | These networks do not need to be exposed as access is managed via VXLAN and iptables maintained by kube-proxy and funneled through MetalLB         |
| All Secrets in .env      | This was done for ease of backup, restore, and getting up and running. This is an anti-practice but this is a home-lab so I have accepted the risk |
| Single Points of Failure | The NAS, Switch, Router, Modem, and Power are all single points of failure. This is an acceptable risk due to practical and budgetary limitations. |

---

## Network Ranges

| Range              | Role                                                                                      |
|--------------------|-------------------------------------------------------------------------------------------|
| 10.42.0.0/16       | Flannel VXLAN *(Pod Networking)*                                                          |
| 10.43.0.0/16       | Kube-Proxy IP Tables *(Service Networking)*                                               |
| 192.168.0.1        | Default gateway                                                                           |
| 192.168.0.2–.99    | DHCP clients                                                                              |
| 192.168.0.100–.109 | Physical nodes (.101, .102, .103)                                                         |
| 192.168.0.110–.119 | Control plane VMs (.110 VIP, .111–.113 VMs)                                               |
| 192.168.0.120–.129 | MetalLB pool (.120 Traefik, .121–.123 worker VMs, .128 Jellyfin direct, .129 AdGuard DNS) |
| 192.168.0.130–.139 | Infrastructure VMs (.131 ts1 — Tailscale subnet router)                                   |
| 192.168.0.200–.209 | Storage (.201 Synology NAS)                                                               |

---

## Hardware

| Type    | Role     | Model                  | Notes                |
|---------|----------|------------------------|----------------------|
| Compute | k3s node | ThinkCentre M710q Tiny | Intel i5 / 16GB DDR4 |
| Compute | k3s node | ThinkCentre M710q Tiny | Intel i5 / 16GB DDR4 |
| Compute | k3s node | ThinkCentre M710q Tiny | Intel i5 / 16GB DDR4 |
| Storage | NAS      | Synology DS418         | 4x 4TB, RAID 5       |
| Network | Switch   | Netgear GS308          | 8-port unmanaged     |
| Network | Router   | EERO Pro 7             | ISP Provided         |
| Network | Modem    | --                     | ISP Provided         |