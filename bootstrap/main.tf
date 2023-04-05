
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
  }
}


// Can't do an initial configuration (JWT auth) in the same workspace
// so instead we use a child workspace for this
// https://github.com/hashicorp/terraform-provider-vault/issues/1198


data "tfe_outputs" "vault_cluster" {
  organization = "fancycorp"
  workspace    = "vault"
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
// TODO: Create JWT Auth method for the main config workspace



module "tfc-auth" {
  source = "hashi-strawb/terraform-cloud-jwt-auth/vault"

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
      token_policies = ["admin"]
    }
  ]
}
