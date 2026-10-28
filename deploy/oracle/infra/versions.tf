terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.11" # >= 9.11, < 10.0
    }
  }
}

# Autenticação via ~/.oci/config (perfil abaixo). Nenhuma credencial vai para o repo.
provider "oci" {
  region              = var.region
  config_file_profile = var.oci_config_profile
}
