provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true # self-signed cert on Proxmox web UI

  ssh {
    agent    = false
    username = "ansible"
    private_key = file(var.ssh_private_key_path)
  }
}
