terraform {
  required_version = ">= 1.5"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.118"
    }
  }
}

# Credenciais via ambiente: PROXMOX_VE_USERNAME/PROXMOX_VE_PASSWORD ou PROXMOX_VE_API_TOKEN.
provider "proxmox" {
  endpoint = var.pve_endpoint
  insecure = true # certificado self-signed padrao do Proxmox
}
