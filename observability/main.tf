# Dashboards e alertas do New Relic versionados em Terraform: o painel de
# negócio (OS e Saga), o painel técnico dos 3 serviços e as condições de
# alerta com notificação por e-mail.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.50"
    }
  }
}

provider "newrelic" {
  account_id = var.account_id
  api_key    = var.api_key
  region     = var.region
}

locals {
  apps     = ["autoshop-api", "autoshop-execution", "autoshop-billing"]
  apps_sql = join(", ", [for a in local.apps : "'${a}'"])
}
