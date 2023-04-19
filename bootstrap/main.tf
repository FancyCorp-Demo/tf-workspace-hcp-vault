
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
      version = ">= 0.43.0"
    }
    multispace = {
      source = "lucymhdavies/multispace"
    }
  }
}


// Can't do an initial configuration (JWT auth) in the same workspace
// so instead we use a child workspace for this
// https://github.com/hashicorp/terraform-provider-vault/issues/1198

provider "tfe" {
  organization = "fancycorp"
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
// TODO: experiment with this...
// Protector for downstream workspace: destroy downstream before destroying this
//

resource "multispace_run" "destroy_downstream" {
  organization = "fancycorp"
  workspace    = "vault-config"

  depends_on = [
    module.tfc-auth
  ]

  # Do not actually kick off an Apply, but create the resource so we can Destroy later
  do_apply = false

  # Kick off the destroy, and wait for it to succeed
  # (this is default behaviour, but make it explicit)
  wait_for_destroy = true
}

