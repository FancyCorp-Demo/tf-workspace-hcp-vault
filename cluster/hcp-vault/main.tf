terraform {
  required_providers {
    hcp = {
      source = "hashicorp/hcp"

      # for cloudwatch
      version = ">= 0.70.0"
    }
  }
}

resource "hcp_hvn" "vault" {
  hvn_id         = "vault-${var.name}"
  cloud_provider = var.cloud
  region         = var.region
  cidr_block     = var.cidr_block
}

/*
resource "hcp_vault_cluster" "this" {
  cluster_id      = "vault-${var.name}"
  hvn_id          = hcp_hvn.vault.hvn_id
  tier            = var.tier
  public_endpoint = var.public_endpoint



  dynamic "audit_log_config" {
    for_each = var.cloudwatch_creds != null ? [1] : []

    content {
      cloudwatch_access_key_id     = var.cloudwatch_creds.key
      cloudwatch_secret_access_key = var.cloudwatch_creds.secret
      cloudwatch_region            = var.cloudwatch_creds.region
    }
  }
}
*/


moved {
  from = hcp_vault_cluster.this
  to   = module.hcp-vault-kerim.hcp_vault_cluster.main
}

module "hcp-vault-kerim" {
  source = "github.com/ksatirli/terraform-hcp-vault-cluster?ref=748e818740bed8a2e498553145a901140f23e0a2"

  cluster_id      = "vault-${var.name}"
  hvn_id          = hcp_hvn.vault.hvn_id
  tier            = lower(var.tier)
  public_endpoint = var.public_endpoint

  audit_log_config = {
    enabled                      = true
    cloudwatch_access_key_id     = var.cloudwatch_creds.key
    cloudwatch_secret_access_key = var.cloudwatch_creds.secret
    cloudwatch_region            = var.cloudwatch_creds.region
  }
}

resource "hcp_vault_cluster_admin_token" "terraform" {
  cluster_id = module.hcp-vault-kerim.hcp_vault_cluster.cluster_id
}
