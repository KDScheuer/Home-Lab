variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in format user@pam!tokenid=secret"
  type        = string
  sensitive   = true
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for Proxmox SSH access"
  type        = string
  default     = "~/.ssh/ansible"
}

variable "ssh_public_key" {
  description = "SSH public key to inject into VMs via cloud-init"
  type        = string
}

variable "proxmox_node_map" {
  description = "Map of VM name to Proxmox node for pinning"
  type        = map(string)
  default = {
    ts1    = "node1"
    ctrl1  = "node1"
    ctrl2  = "node2"
    ctrl3  = "node3"
    work1  = "node1"
    work2  = "node2"
    work3  = "node3"
  }
}

variable "network_gateway" {
  description = "Default gateway for all VMs"
  type        = string
  default     = "192.168.0.1"
}

variable "network_dns" {
  description = "DNS servers for all VMs"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "network_domain" {
  description = "Domain name for all VMs"
  type        = string
  default     = "kds-dev.com"
}

variable "template_id" {
  description = "Proxmox VM ID of the Rocky 9 cloud template"
  type        = number
  default     = 9000
}

variable "storage_pool" {
  description = "Proxmox storage pool name for VM disks"
  type        = string
  default     = "vm-disks"
}

variable "cloudinit_storage" {
  description = "Proxmox storage pool for cloud-init drives"
  type        = string
  default     = "vm-disks"
}
