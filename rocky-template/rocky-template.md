# Runbook: Build Rocky 9 Cloud Template

## Overview

Builds a Rocky 9 cloud image template in Proxmox using VM ID 9000.
The template disk and cloud-init snippet both live on shared NFS storage
(`vm-disks`) making them accessible from all cluster nodes. Terraform
clones this template when provisioning new VMs.

This process is manual by design — the template is built once and
rebuilt only when a new Rocky 9 base image is needed. See the notes
section regarding Packer as the production alternative.

---

## Prerequisites

- Proxmox cluster fully configured
- NFS storage (`vm-disks`) mounted and accessible on all nodes with
  content types `images,snippets` enabled
- SSH access to node1 as the ansible user

---

## Steps

### 1. SSH into node1 and switch to root

```bash
ssh ansible@192.168.0.101
sudo su
cd /tmp
```

### 2. Download the Rocky 9 cloud image

```bash
wget https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2
```

### 3. Create the base VM

```bash
qm create 9000 \
  --name rocky9-cloud-template \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26 \
  --agent enabled=1
```

### 4. Import the cloud image disk into NFS storage

```bash
qm importdisk 9000 \
  /tmp/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 \
  vm-disks
```

### 5. Find the imported disk name

After import the disk is in an `unused` state. The name Proxmox assigns
is not always predictable so you must check the actual name before
attaching it:

```bash
qm config 9000
```

Look for the `unused0` line in the output. It will look similar to:

```
unused0: vm-disks:9000/vm-9000-disk-0.raw
```

The value after `unused0:` is the exact string you need for the next
step. Copy it exactly.

### 6. Attach the disk to the VM

Replace the disk path below with the exact value from `unused0` in the
previous step:

```bash
qm set 9000 \
  --scsihw virtio-scsi-pci \
  --scsi0 vm-disks:9000/vm-9000-disk-0.raw,discard=on
```

### 7. Add the cloud-init drive

```bash
qm set 9000 --ide2 vm-disks:cloudinit
```

### 8. Set boot order

```bash
qm set 9000 --boot order=scsi0
```

### 9. Enable serial console

Required for cloud-init to function correctly on Proxmox:

```bash
qm set 9000 --serial0 socket --vga serial0
```

### 10. Set cloud-init defaults

These are base defaults only — Terraform overrides hostname, IP, and
SSH keys per-VM at clone time:

```bash
qm set 9000 \
  --ciuser ansible \
  --ipconfig0 ip=dhcp
```

### 11. Convert to template

```bash
qm template 9000
```

**Expected warning — not an error:**

```
/usr/bin/chattr: Operation not supported while reading flags on /mnt/pve/vm-disks/...
command '/usr/bin/chattr +i ...' failed: exit code 1
```

This warning appears every time a template is built on NFS storage.
Proxmox attempts to set the immutable file attribute (`chattr +i`) on
the template disk but NFS does not support this attribute. The template
is created successfully despite this message and functions correctly.
You can safely ignore it.

### 12. Verify the template was created

```bash
qm config 9000
```

Confirm the following are present in the output:

```
template: 1
boot: order=scsi0
scsi0: vm-disks:9000/base-9000-disk-0.raw,...
serial0: socket
```

### 13. Create the cloud-init snippet

Ensure the snippets directory exists on the NFS share:

```bash
mkdir -p /mnt/pve/vm-disks/snippets
```

Create the cloud-init file. Replace the SSH public key with the
contents of `~/.ssh/id_ed25519.pub` from your management machine:

```bash
vi /mnt/pve/vm-disks/snippets/rocky9-cloudinit.yml
```

File contents:

```yaml
#cloud-config

users:
  - name: ansible
    groups: wheel
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - ssh-ed25519 AAAA...your-public-key-here

disable_root: true
ssh_pwauth: false

write_files:
  - path: /etc/ssh/sshd_config.d/99-hardening.conf
    content: |
      PasswordAuthentication no
      PubkeyAuthentication yes
      PermitRootLogin no
    permissions: '0600'

runcmd:
  - systemctl restart sshd
  - systemctl enable --now qemu-guest-agent

final_message: "Cloud-init complete. System ready."
```

**Note on selinux:** Do not add a `selinux` block to this file. The
cloud-init schema validator does not support it and will fail
validation. SELinux enforcement is handled by the Ansible os_baseline
role after the VM is provisioned.

### 14. Validate the cloud-init file syntax

```bash
cloud-init schema --config-file /mnt/pve/vm-disks/snippets/rocky9-cloudinit.yml
```

Expected output:

```
Valid schema /mnt/pve/vm-disks/snippets/rocky9-cloudinit.yml
```

Do not proceed if this returns errors.

### 15. Apply the cloud-init snippet to the template

```bash
qm set 9000 --cicustom "user=vm-disks:snippets/rocky9-cloudinit.yml"
```

### 16. Final verification

```bash
qm config 9000
```

Confirm all of the following are present:

```
template: 1
boot: order=scsi0
cicustom: user=vm-disks:snippets/rocky9-cloudinit.yml
ciuser: ansible
scsi0: vm-disks:9000/base-9000-disk-0.raw,discard=on,size=10G
scsihw: virtio-scsi-pci
serial0: socket
vga: serial0
```

### 17. Clean up

```bash
rm /tmp/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2
exit
```

### 18. Verify template is accessible from all nodes

From node2 or node3, confirm the template disk is visible on shared
storage:

```bash
pvesm list vm-disks
```

You should see `base-9000-disk-0.raw` listed. If it appears the
template is accessible cluster-wide and Terraform can clone from any
node.

---

## Rebuilding the template

To rebuild with a newer Rocky 9 image:

```bash
# destroy the existing template
qm destroy 9000

# repeat all steps above
```

Note that destroying the template does not affect any VMs already
cloned from it — cloned VMs have their own independent disk copies.
The cloud-init snippet does not need to be recreated unless the
content has changed.

---

## Git repository

The cloud-init snippet is committed to the repository under:

```
cloud-init/rocky9-cloudinit.yml
```

This is the source of truth. If the NFS snippet is ever lost or
corrupted, restore it from Git:

```bash
cp rocky9-cloudinit.yml \
  /mnt/pve/vm-disks/snippets/rocky9-cloudinit.yml
```

---

## Notes

**Why manual:** The template is built once and rarely rebuilt.
Automating a process that runs once or twice a year has negative ROI
compared to a well-documented runbook.

**Production alternative:** In a production environment this process
would be handled by [Packer](https://www.packer.io/) — HashiCorp's
image building tool. Packer builds VM images from a declarative config,
runs provisioners against them, and outputs a Proxmox template
automatically. It is designed to work alongside Terraform in the same
way this runbook feeds into the Terraform VM provisioning workflow.

**Template HA:** Both the template disk and cloud-init snippet live on
`vm-disks` NFS shared storage and are therefore accessible from all 3
Proxmox nodes. The template does not need to be enrolled in Proxmox HA
— it is a static disk image, not a running VM.

**NFS storage content types:** The `vm-disks` storage must have both
`images` and `snippets` enabled as content types. This is configured
in the Ansible `proxmox_storage` role. If snippets are not enabled,
`qm set --cicustom` will fail with a storage error.