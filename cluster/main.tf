
terraform {
  cloud {
    organization = "fancycorp"

    workspaces {
      name = "vault"
    }
  }
}

terraform {
  required_providers {
    hcp = {
      source = "hashicorp/hcp"
    }
    multispace = {
      source = "lucymhdavies/multispace"
    }
  }
}


//
// HCP Vault Cluster
//

provider "hcp" {}

module "hcp-vault" {
  source = "./hcp-vault"

  #  name       = "azure-london"
  #  cloud      = "azure"
  #  region     = "uksouth"

  name   = var.hcp_vault_cluster_name
  cloud  = var.hcp_platform
  region = var.hcp_region

  # To make demos easier
  public_endpoint = true
}





//
// Serves two purposes:
// * Workaround for Run Triggers not auto-applying downstream workspaces
// * Protector for downstream workspace: destroy downstream before destroying this
//

resource "multispace_run" "downstream" {
  organization = "fancycorp"
  workspace    = "vault-config-bootstrap"

  depends_on = [
    module.hcp-vault
  ]

  # Kick off the apply/destroy, and wait for it to succeed
  # (this is default behaviour, but make it explicit)
  wait_for_apply   = true
  wait_for_destroy = true
}
