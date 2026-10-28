variable "region" {
  description = "Região home do tenancy (Always Free só vale na home region). Ex.: us-ashburn-1"
  type        = string
}

variable "oci_config_profile" {
  description = "Perfil de ~/.oci/config usado pelo provider."
  type        = string
  default     = "DEFAULT"
}

variable "compartment_ocid" {
  description = "OCID do compartment (para o root, use o OCID do tenancy)."
  type        = string
}

variable "ssh_public_key" {
  description = "Conteúdo da chave SSH PÚBLICA (ssh-ed25519 ... / ssh-rsa ...) autorizada no usuário 'ubuntu'."
  type        = string
}

variable "admin_cidr" {
  description = "CIDR autorizado a acessar o SSH (22) da VM, ex.: 203.0.113.7/32. Sem default de propósito; 0.0.0.0/0 é rejeitado."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr deve ser um CIDR IPv4 válido e diferente de 0.0.0.0/0 (use seu IP/32)."
  }
}

variable "shape" {
  description = "VM.Standard.A1.Flex (aarch64, padrão) ou VM.Standard.E2.1.Micro (x86_64, 1 GB; fallback quando A1 der 'Out of host capacity')."
  type        = string
  default     = "VM.Standard.A1.Flex"

  validation {
    condition     = contains(["VM.Standard.A1.Flex", "VM.Standard.E2.1.Micro"], var.shape)
    error_message = "shape deve ser VM.Standard.A1.Flex ou VM.Standard.E2.1.Micro."
  }
}

variable "ocpus" {
  description = "OCPUs (só A1.Flex). Cota Always Free atual da doc: 2 OCPU / 12 GB no total do tenancy."
  type        = number
  default     = 1

  validation {
    condition     = var.ocpus >= 1 && var.ocpus <= 2
    error_message = "ocpus deve estar entre 1 e 2 (teto Always Free)."
  }
}

variable "memory_in_gbs" {
  description = "RAM em GB (só A1.Flex)."
  type        = number
  default     = 6

  validation {
    condition     = var.memory_in_gbs >= 1 && var.memory_in_gbs <= 12
    error_message = "memory_in_gbs deve estar entre 1 e 12 (teto Always Free)."
  }
}

variable "boot_volume_size_in_gbs" {
  description = "Boot volume em GB. Mínimo 47; o teto Always Free é 200 GB somando todas as VMs/volumes."
  type        = number
  default     = 50

  validation {
    condition     = var.boot_volume_size_in_gbs >= 47 && var.boot_volume_size_in_gbs <= 200
    error_message = "boot_volume_size_in_gbs deve estar entre 47 e 200."
  }
}

variable "availability_domain_index" {
  description = "Índice do Availability Domain. Se A1 der 'Out of host capacity', tente outro AD (0, 1, 2) quando a região tiver mais de um."
  type        = number
  default     = 0
}

variable "name_prefix" {
  description = "Prefixo dos nomes dos recursos."
  type        = string
  default     = "zombizoid"
}

variable "vcn_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "repo_url" {
  description = "Repositório (público) clonado pelo cloud-init. Precisa conter deploy/oracle/ já com push feito."
  type        = string
  default     = "https://github.com/moisesjuniorops/ZombiZoid-deployment-oracle.git"
}

variable "repo_ref" {
  description = "Branch ou tag a clonar."
  type        = string
  default     = "main"
}
