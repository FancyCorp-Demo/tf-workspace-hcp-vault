
terraform {
  cloud {
    organization = "fancycorp"

    workspaces {
      name = "vault-config-bootstrap"
    }
  }
}

terraform {
  required_providers {
    hcp = {
      source = "hashicorp/hcp"
    }
    vault = {
      source = "hashicorp/vault"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.45.0" # for tfe_workspace_run
    }
  }
}


// Can't do an initial configuration (JWT auth) in the same workspace
// so instead we use a child workspace for this
// https://github.com/hashicorp/terraform-provider-vault/issues/1198

provider "tfe" {
  organization = "fancycorp"
}

provider "hcp" {
  project_id = "d6c96d2b-616b-4cb8-b78c-9e17a78c2167"
}


data "tfe_outputs" "vault_cluster" {
  workspace = "vault"
}


//
// Admin Policy
//

provider "vault" {
  address   = data.tfe_outputs.vault_cluster.values.vault_public_endpoint_url
  token     = data.tfe_outputs.vault_cluster.values.vault_admin_token
  namespace = data.tfe_outputs.vault_cluster.values.vault_namespace
}

data "vault_policy_document" "admin" {
  rule {
    path         = "*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    description  = "full admin permissions on everything"
  }
}

resource "vault_policy" "admin" {
  name   = "admin"
  policy = data.vault_policy_document.admin.hcl
}

module "tfc-auth" {
  source  = "hashi-strawb/terraform-cloud-jwt-auth/vault"
  version = ">= 0.2.1"
  #source = "./terraform-vault-terraform-cloud-jwt-auth"

  terraform = {
    org = "fancycorp"
  }

  vault = {
    addr      = data.tfe_outputs.vault_cluster.values.vault_public_endpoint_url
    namespace = data.tfe_outputs.vault_cluster.values.vault_namespace
    auth_path = "tfc/fancycorp"
  }

  roles = [
    {
      workspace_name = "vault-config"
      token_policies = [
        vault_policy.admin.name
      ]
    }
  ]
}




//
// Protector for downstream workspace: destroy downstream before destroying this
//

data "tfe_workspace" "downstream" {
  name = "vault-config"
}
resource "tfe_workspace_run" "downstream" {
  workspace_id = data.tfe_workspace.downstream.id

  depends_on = [
    module.tfc-auth
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

