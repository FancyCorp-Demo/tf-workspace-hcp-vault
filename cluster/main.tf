
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

// If we've created a Cloudwatch user, use those creds
data "tfe_outputs" "vault_monitoring" {
  workspace = "vault-monitoring"
}

module "hcp-vault" {
  source = "./hcp-vault"

  #  name       = "azure-london"
  #  cloud      = "azure"
  #  region     = "uksouth"

  name   = var.hcp_vault_cluster_name
  cloud  = var.hcp_platform
  region = var.hcp_region

  tier = var.hcp_vault_tier

  min_vault_version = var.min_vault_version

  # To make demos easier
  public_endpoint = true

  # if we have creds, use them
  cloudwatch_creds = try(
    {
      key    = data.tfe_outputs.vault_monitoring.values.creds.id
      secret = data.tfe_outputs.vault_monitoring.values.creds.secret
    },
    null
  )
}





//
// Protector for downstream workspace: destroy downstream before destroying this
//

provider "tfe" {
  organization = "fancycorp"
}

data "tfe_workspace" "downstream" {
  for_each = toset([
    "vault-config-bootstrap",
    "vault-monitoring"
  ])

  name = each.key
}

resource "tfe_workspace_run" "downstream" {
  for_each = data.tfe_workspace.downstream

  workspace_id = each.value.id

  depends_on = [
    module.hcp-vault
  ]

  # Kick off a fire-and-forget Apply
  # (We have run triggers already, but those still require manual approval
  apply {
    manual_confirm = false # Let TF confirm this itself
    wait_for_run   = false # Fire-and-Forget
  }

  # Kick off the destroy, and wait for it to succeed
  # (this is default behaviour, but make it explicit)
  destroy {
    manual_confirm = false # Let TF confirm this itself
    retry          = false # Only try once
    wait_for_run   = true  # Wait until destroy has finished before removing this resource
  }
}
