
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

provider "hcp" {
  project_id = "d6c96d2b-616b-4cb8-b78c-9e17a78c2167"
}

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
resource "tfe_workspace_run" "downstream" {
  workspace_id = data.tfe_workspace.downstream.id

  depends_on = [
    module.hcp-vault
  ]

  # Kick off a fire-and-forget Apply
  # (We have run triggers already, but those still require manual approval
  apply {
    manual_confirm = false # Let TF confirm this itself
    wait_for_run   = true  # Fire-and-Forget
  }

  # Kick off the destroy, and wait for it to succeed
  # (this is default behaviour, but make it explicit)
  destroy {
    manual_confirm = false # Let TF confirm this itself
    retry          = false # Only try once
    wait_for_run   = true  # Wait until destroy has finished before removing this resource
  }
}

