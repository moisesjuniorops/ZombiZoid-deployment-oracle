data "oci_identity_availability_domains" "this" {
  compartment_id = var.compartment_ocid
}

# O filtro por shape garante a arquitetura certa (aarch64 para A1, x86_64 para E2.1.Micro).
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04" # Python 3.12, exigido pelo nextcord 3.2.0
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  is_flex = var.shape == "VM.Standard.A1.Flex"

  # Sem segredos aqui: config.yaml é enviado depois (push-config.sh).
  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    repo_url = var.repo_url
    repo_ref = var.repo_ref
  })
}

resource "oci_core_instance" "bot" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[var.availability_domain_index].name
  display_name        = "${var.name_prefix}-bot"
  shape               = var.shape

  dynamic "shape_config" {
    for_each = local.is_flex ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.this.id
    assign_public_ip = true
    hostname_label   = var.name_prefix
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(local.cloud_init)
  }

  # Não destruir a VM só porque saiu uma imagem Ubuntu mais nova.
  lifecycle {
    ignore_changes = [source_details[0].source_id]

    precondition {
      condition     = length(data.oci_core_images.ubuntu.images) > 0
      error_message = "Nenhuma imagem Ubuntu 24.04 encontrada para o shape ${var.shape} nesta região."
    }
    precondition {
      condition     = var.availability_domain_index < length(data.oci_identity_availability_domains.this.availability_domains)
      error_message = "availability_domain_index fora do intervalo de ADs desta região."
    }
  }

  preserve_boot_volume = false
}
