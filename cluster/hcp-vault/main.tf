terraform {
  required_providers {
    hcp = {
      source = "hashicorp/hcp"
    }
  }
}

resource "hcp_hvn" "vault" {
  hvn_id         = "vault-${var.name}"
  cloud_provider = var.cloud
  region         = var.region
  cidr_block     = var.cidr_block
}

resource "hcp_vault_cluster" "this" {
  cluster_id      = "vault-${var.name}"
  hvn_id          = hcp_hvn.vault.hvn_id
  tier            = var.tier
  public_endpoint = var.public_endpoint
}
