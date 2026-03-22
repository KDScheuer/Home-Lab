# Worker VMs
# Uncomment after ts1 and control plane VMs are validated
#
# All worker VMs are pinned to their respective nodes.
# k3s/Talos handles workload rescheduling on node failure.
# Proxmox HA is NOT enabled for these VMs intentionally.
# Workers receive more RAM than control plane VMs as they
# run all application workloads.

# resource "proxmox_virtual_environment_vm" "work01" {
#   vm_id     = 121
#   name      = "work01"
#   node_name = var.proxmox_node_map["work01"]
#   tags      = ["k8s", "worker"]
#
#   description = "Kubernetes worker node 1 - pinned to node1"
#
#   clone {
#     vm_id = var.template_id
#     full  = true
#   }
#
#   cpu {
#     cores = 4
#     type  = "host"
#   }
#
#   memory {
#     dedicated = 8192
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
#         address = "192.168.50.121/24"
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
# resource "proxmox_virtual_environment_vm" "work02" {
#   vm_id     = 122
#   name      = "work02"
#   node_name = var.proxmox_node_map["work02"]
#   tags      = ["k8s", "worker"]
#
#   description = "Kubernetes worker node 2 - pinned to node2"
#
#   clone {
#     vm_id = var.template_id
#     full  = true
#   }
#
#   cpu {
#     cores = 4
#     type  = "host"
#   }
#
#   memory {
#     dedicated = 8192
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
#         address = "192.168.50.122/24"
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
# resource "proxmox_virtual_environment_vm" "work03" {
#   vm_id     = 123
#   name      = "work03"
#   node_name = var.proxmox_node_map["work03"]
#   tags      = ["k8s", "worker"]
#
#   description = "Kubernetes worker node 3 - pinned to node3"
#
#   clone {
#     vm_id = var.template_id
#     full  = true
#   }
#
#   cpu {
#     cores = 4
#     type  = "host"
#   }
#
#   memory {
#     dedicated = 8192
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
#         address = "192.168.50.123/24"
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
