
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
// TODO: experiment with this...
// Protector for downstream workspace: destroy downstream before destroying this
//

resource "multispace_run" "destroy_downstream" {
organization = "fancycorp"
  workspace = "vault-config-bootstrap"

  depends_on = [
    module.hcp-vault
  ]

  # Do not actually kick off an Apply, but create the resource so we can Destroy later
  do_apply = false

  # Kick off the destroy, and wait for it to succeed
  # (this is default behaviour, but make it explicit)
  wait_for_destroy = true
}
