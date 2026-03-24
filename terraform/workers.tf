# work1.kds-dev.com
resource "proxmox_virtual_environment_vm" "work1" {
  vm_id           = 121
  name            = "work1"
  node_name       = var.proxmox_node_map["work1"]
  tags            = ["k3s", "worker"]
  stop_on_destroy = true

  description = "k3s worker node 1 - pinned to node1"

  clone {
    vm_id = var.template_id
    full  = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 10240
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
        address = "192.168.50.121/24"
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

# work2.kds-dev.com
resource "proxmox_virtual_environment_vm" "work2" {
  vm_id           = 122
  name            = "work2"
  node_name       = var.proxmox_node_map["work2"]
  tags            = ["k3s", "worker"]
  stop_on_destroy = true

  description = "k3s worker node 2 - pinned to node2"

  clone {
    vm_id     = var.template_id
    node_name = "node1"
    full      = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 10240
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
        address = "192.168.50.122/24"
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

# work3.kds-dev.com
resource "proxmox_virtual_environment_vm" "work3" {
  vm_id           = 123
  name            = "work3"
  node_name       = var.proxmox_node_map["work3"]
  tags            = ["k3s", "worker"]
  stop_on_destroy = true

  description = "k3s worker node 3 - pinned to node3"

  clone {
    vm_id     = var.template_id
    node_name = "node1"
    full      = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 10240
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
        address = "192.168.50.123/24"
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
