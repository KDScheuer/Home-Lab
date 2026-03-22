# Control plane VMs
# Uncomment after ts1 is validated and working
#
# All control plane VMs are pinned to their respective nodes.
# k3s/Talos handles control plane HA — Proxmox HA is NOT enabled
# for these VMs intentionally.

# resource "proxmox_virtual_environment_vm" "ctrl01" {
#   vm_id     = 111
#   name      = "ctrl01"
#   node_name = var.proxmox_node_map["ctrl01"]
#   tags      = ["k8s", "control-plane"]
#
#   description = "Kubernetes control plane node 1 - pinned to node1"
#
#   clone {
#     vm_id = var.template_id
#     full  = true
#   }
#
#   cpu {
#     cores = 2
#     type  = "host"
#   }
#
#   memory {
#     dedicated = 2048
#   }
#
#   disk {
#     datastore_id = var.storage_pool
#     interface    = "scsi0"
#     size         = 50
#     file_format  = "raw"
#   }
#
#   network_device {
#     bridge = "vmbr0"
#     model  = "virtio"
#   }
#
#   operating_system {
#     type = "l26"
#   }
#
#   agent {
#     enabled = true
#   }
#
#   serial_device {}
#
#   initialization {
#     datastore_id = var.cloudinit_storage
#
#     ip_config {
#       ipv4 {
#         address = "192.168.50.111/24"
#         gateway = var.network_gateway
#       }
#     }
#
#     dns {
#       servers = var.network_dns
#       domain  = var.network_domain
#     }
#
#     user_account {
#       username = "ansible"
#       keys     = [var.ssh_public_key]
#     }
#
#     user_data_file_id = "vm-disks:snippets/rocky9-cloudinit.yml"
#   }
#
#   lifecycle {
#     ignore_changes = [disk]
#   }
# }
#
# resource "proxmox_virtual_environment_vm" "ctrl02" {
#   vm_id     = 112
#   name      = "ctrl02"
#   node_name = var.proxmox_node_map["ctrl02"]
#   tags      = ["k8s", "control-plane"]
#
#   description = "Kubernetes control plane node 2 - pinned to node2"
#
#   clone {
#     vm_id = var.template_id
#     full  = true
#   }
#
#   cpu {
#     cores = 2
#     type  = "host"
#   }
#
#   memory {
#     dedicated = 2048
#   }
#
#   disk {
#     datastore_id = var.storage_pool
#     interface    = "scsi0"
#     size         = 50
#     file_format  = "raw"
#   }
#
#   network_device {
#     bridge = "vmbr0"
#     model  = "virtio"
#   }
#
#   operating_system {
#     type = "l26"
#   }
#
#   agent {
#     enabled = true
#   }
#
#   serial_device {}
#
#   initialization {
#     datastore_id = var.cloudinit_storage
#
#     ip_config {
#       ipv4 {
#         address = "192.168.50.112/24"
#         gateway = var.network_gateway
#       }
#     }
#
#     dns {
#       servers = var.network_dns
#       domain  = var.network_domain
#     }
#
#     user_account {
#       username = "ansible"
#       keys     = [var.ssh_public_key]
#     }
#
#     user_data_file_id = "vm-disks:snippets/rocky9-cloudinit.yml"
#   }
#
#   lifecycle {
#     ignore_changes = [disk]
#   }
# }
#
# resource "proxmox_virtual_environment_vm" "ctrl03" {
#   vm_id     = 113
#   name      = "ctrl03"
#   node_name = var.proxmox_node_map["ctrl03"]
#   tags      = ["k8s", "control-plane"]
#
#   description = "Kubernetes control plane node 3 - pinned to node3"
#
#   clone {
#     vm_id = var.template_id
#     full  = true
#   }
#
#   cpu {
#     cores = 2
#     type  = "host"
#   }
#
#   memory {
#     dedicated = 2048
#   }
#
#   disk {
#     datastore_id = var.storage_pool
#     interface    = "scsi0"
#     size         = 50
#     file_format  = "raw"
#   }
#
#   network_device {
#     bridge = "vmbr0"
#     model  = "virtio"
#   }
#
#   operating_system {
#     type = "l26"
#   }
#
#   agent {
#     enabled = true
#   }
#
#   serial_device {}
#
#   initialization {
#     datastore_id = var.cloudinit_storage
#
#     ip_config {
#       ipv4 {
#         address = "192.168.50.113/24"
#         gateway = var.network_gateway
#       }
#     }
#
#     dns {
#       servers = var.network_dns
#       domain  = var.network_domain
#     }
#
#     user_account {
#       username = "ansible"
#       keys     = [var.ssh_public_key]
#     }
#
#     user_data_file_id = "vm-disks:snippets/rocky9-cloudinit.yml"
#   }
#
#   lifecycle {
#     ignore_changes = [disk]
#   }
# }
