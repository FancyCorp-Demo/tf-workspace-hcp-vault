
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
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.45.0" # for tfe_workspace_run
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
// Protector for downstream workspace: destroy downstream before destroying this
//

provider "tfe" {
  organization = "fancycorp"
}

data "tfe_workspace" "downstream" {
  name = "vault-config-bootstrap"
}
resource "tfe_workspace_run" "destroy_downstream" {
  workspace_id = data.tfe_workspace.downstream.id

  depends_on = [
    module.hcp-vault
  ]

  # Do not actually kick off an Apply, but create the resource so we can Destroy later
  # (i.e. we're excluding the apply{} block

  # Kick off the destroy, and wait for it to succeed
  # (this is default behaviour, but make it explicit)
  destroy {
    manual_confirm = false # Let TF confirm this itself
    retry          = false # Only try once
    wait_for_run   = true  # Wait until destroy has finished before removing this resource
  }
}

