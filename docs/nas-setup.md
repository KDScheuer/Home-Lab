# Synology NAS Setup

## Identity

| Property | Value              |
|----------|--------------------|
| Hostname | `nas.kds-dev.com`  |
| IP       | `192.168.0.201`   |

---

## Storage

| Property   | Value                     |
|------------|---------------------------|
| Volume     | `Volume 1` — all 4 disks  |
| RAID Level | RAID 6                    |
| Filesystem | btrfs                     |

---

## NFS Share

| Property        | Value                   |
|-----------------|-------------------------|
| Export path     | `/volume1/networkShare` |
| NFS version     | NFSv3                   |
| Allowed network | `192.168.0.0/21`       |
| Permissions     | Read/Write              |
| User squash     | Map all users to admin  |

---

## Subdirectories

| Name       | Purpose                                                                                          |
|------------|--------------------------------------------------------------------------------------------------|
| `srv`      | Application persistent storage mounted on k3s nodes as NFS PVs (e.g. `/srv/jellyfin/media`, `/srv/immich/files`) |
| `pve-iso`  | ISO images for Proxmox VM installs                                                               |
| `vm-disks` | VM disks, templates, and cloud-init configs — configured as a Proxmox storage pool (see `ansible/roles/proxmox_storage`) |