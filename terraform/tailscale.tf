resource "proxmox_virtual_environment_vm" "ts1" {
  vm_id     = 131
  name      = "ts1"
  node_name = var.proxmox_node_map["ts1"]
  tags      = ["tailscale", "ha"]

  description = "Tailscale subnet router - provides remote access to homelab LAN"

  clone {
    vm_id = var.template_id
    full  = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 1024
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
        address = "192.168.0.131/24"
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
    ignore_changes = [
      disk,
      vga,
    ]
  }
}
