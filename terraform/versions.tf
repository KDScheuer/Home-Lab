terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}
