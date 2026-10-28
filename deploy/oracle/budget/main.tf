# Budget de US$ 1/mes no tenancy inteiro: qualquer cobranca (real ou prevista) dispara e-mail.
# Budgets sao gratuitos. Uso: terraform init && terraform apply (credenciais em ~/.oci/config).
terraform {
  required_version = ">= 1.5"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.11"
    }
  }
}

variable "region" {
  type    = string
  default = "us-ashburn-1"
}
variable "tenancy_ocid" { type = string }
variable "alert_email" { type = string }

provider "oci" {
  region = var.region
}

resource "oci_budget_budget" "zero_cost" {
  compartment_id = var.tenancy_ocid
  display_name   = "zero-cost-guard"
  description    = "Alerta qualquer custo na conta (objetivo: US$ 0)"
  amount         = 1
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [var.tenancy_ocid]
}

# Dispara ao gastar US$ 0,01 (1% de US$ 1) de verdade.
resource "oci_budget_alert_rule" "actual_any" {
  budget_id      = oci_budget_budget.zero_cost.id
  display_name   = "custo-real-qualquer"
  type           = "ACTUAL"
  threshold      = 1
  threshold_type = "PERCENTAGE"
  recipients     = var.alert_email
  message        = "Oracle Cloud registrou custo real na conta. Verifique Billing > Cost Analysis."
}

# Dispara se a previsao do mes passar de US$ 1.
resource "oci_budget_alert_rule" "forecast" {
  budget_id      = oci_budget_budget.zero_cost.id
  display_name   = "custo-previsto"
  type           = "FORECAST"
  threshold      = 100
  threshold_type = "PERCENTAGE"
  recipients     = var.alert_email
  message        = "Previsao de custo na Oracle Cloud passou de US$ 1 neste mes."
}

output "budget_id" { value = oci_budget_budget.zero_cost.id }
