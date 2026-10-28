# Ubuntu 24.04 cloud image baixada direto pelo Proxmox (conteudo "import" do PVE 9).
resource "proxmox_download_file" "ubuntu" {
  node_name    = var.pve_node
  datastore_id = var.image_datastore
  content_type = "import"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "noble-server-cloudimg-amd64.qcow2"
  overwrite    = false
}

resource "proxmox_virtual_environment_vm" "zomboid" {
  node_name   = var.pve_node
  vm_id       = var.vm_id
  name        = var.vm_name
  description = "Project Zomboid B42 + bot ZombiZoid (gerenciado por Terraform)"
  tags        = ["zomboid", "terraform"]
  on_boot     = true
  started     = true

  machine       = "q35"
  bios          = "seabios"
  scsi_hardware = "virtio-scsi-single"

  agent {
    enabled = true
    timeout = "5m"
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.datastore
    import_from  = proxmox_download_file.ubuntu.id
    interface    = "scsi0"
    size         = var.disk_gb
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  serial_device {}

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.datastore
    ip_config {
      ipv4 {
        address = var.ip_cidr
        gateway = var.gateway
      }
    }
    dns {
      servers = var.dns_servers
    }
    user_account {
      username = "ubuntu"
      keys     = [trimspace(var.ssh_public_key)]
    }
  }

  lifecycle {
    ignore_changes = [disk[0].import_from]
  }
}

output "ssh_command" {
  value = "ssh ubuntu@${split("/", var.ip_cidr)[0]}"
}
