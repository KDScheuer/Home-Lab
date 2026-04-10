# Control plane VMs
# Uncomment after ts1 is validated and working
#
# All control plane VMs are pinned to their respective nodes.
# k3s handles control plane HA — Proxmox HA is NOT enabled
# for these VMs intentionally.

resource "proxmox_virtual_environment_vm" "ctrl1" {
  vm_id           = 111
  name            = "ctrl1"
  node_name       = var.proxmox_node_map["ctrl1"]
  tags            = ["k3s", "control-plane"]
  stop_on_destroy = true

  description = "k3s control plane node 1 - pinned to node1"

  clone {
    vm_id = var.template_id
    full  = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = 50
    file_format  = "raw"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
  }

  serial_device {}

  initialization {
    datastore_id = var.cloudinit_storage

    ip_config {
      ipv4 {
        address = "192.168.0.111/24"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.network_dns
      domain  = var.network_domain
    }

    user_account {
      username = "ansible"
      keys     = [var.ssh_public_key]
    }

    user_data_file_id = "vm-disks:snippets/rocky9-cloudinit.yml"
  }

  lifecycle {
    ignore_changes = [disk, vga]
  }
}

resource "proxmox_virtual_environment_vm" "ctrl2" {
  vm_id           = 112
  name            = "ctrl2"
  node_name       = var.proxmox_node_map["ctrl2"]
  tags            = ["k3s", "control-plane"]
  stop_on_destroy = true

  description = "k3s control plane node 2 - pinned to node2"

  clone {
    vm_id     = var.template_id
    node_name = "node1"
    full      = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }
#
  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = 50
    file_format  = "raw"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
  }

  serial_device {}

  initialization {
    datastore_id = var.cloudinit_storage

    ip_config {
      ipv4 {
        address = "192.168.0.112/24"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.network_dns
      domain  = var.network_domain
    }

    user_account {
      username = "ansible"
      keys     = [var.ssh_public_key]
    }

    user_data_file_id = "vm-disks:snippets/rocky9-cloudinit.yml"
  }

  lifecycle {
    ignore_changes = [disk, vga]
  }
}

resource "proxmox_virtual_environment_vm" "ctrl3" {
  vm_id           = 113
  name            = "ctrl3"
  node_name       = var.proxmox_node_map["ctrl3"]
  tags            = ["k3s", "control-plane"]
  stop_on_destroy = true

  description = "k3s control plane node 3 - pinned to node3"

  clone {
    vm_id     = var.template_id
    node_name = "node1"
    full      = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = 50
    file_format  = "raw"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
  }

  serial_device {}

  initialization {
    datastore_id = var.cloudinit_storage

    ip_config {
      ipv4 {
        address = "192.168.0.113/24"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.network_dns
      domain  = var.network_domain
    }

    user_account {
      username = "ansible"
      keys     = [var.ssh_public_key]
    }

    user_data_file_id = "vm-disks:snippets/rocky9-cloudinit.yml"
  }

  lifecycle {
    ignore_changes = [disk, vga]
  }
}
