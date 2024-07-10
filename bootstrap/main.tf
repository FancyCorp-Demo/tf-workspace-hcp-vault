
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

variable "auth_method" {
  default = "admin_token"
}
data "tfe_workspace_ids" "all" {
  names = ["*"]
}

resource "tfe_variable" "vault_auth_method" {
  key          = "auth_method"
  value        = "dynamic_creds"
  category     = "terraform"
  workspace_id = data.tfe_workspace_ids.all.ids[terraform.workspace]

  description = "What Vault Auth method should we use?"

  depends_on = [
    # don't set the auth method var unless the auth has been created
    module.tfc-auth-self
  ]
}


provider "vault" {
  address = data.tfe_outputs.vault_cluster.values.vault_public_endpoint_url

  # If we've not yet bootstrapped... use an admin token for auth
  # otherwise, use dynamic creds (by setting token to null)
  token = var.auth_method == "admin_token" ? data.tfe_outputs.vault_cluster.values.vault_admin_token : null

  namespace = data.tfe_outputs.vault_cluster.values.vault_namespace
}

// whoami?
data "vault_generic_secret" "whoami" {
  path = "auth/token/lookup-self"
}

output "whoami" {
  value = nonsensitive(
    merge(data.vault_generic_secret.whoami.data, {
      # Remove the ID from the output, and then the rest is non-sensitive
      "id" = "REDACTED",
      }
    )
  )
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

  depends_on = [
    # ensure that the bootstrap auth self-modifier is the last thing to be deleted
    module.tfc-auth-self
  ]
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
    # The rest of the Vault config, split up by use-case
    {
      workspace_name = "vault-config"
      token_policies = [
        vault_policy.admin.name
      ]
    },
    {
      workspace_name = "vault-config-aws"
      token_policies = [
        vault_policy.admin.name
      ]
    },
    {
      workspace_name = "vault-config-pki"
      token_policies = [
        vault_policy.admin.name
      ]
    },
  ]
}

module "tfc-auth-lmhd" {
  source  = "hashi-strawb/terraform-cloud-jwt-auth/vault"
  version = ">= 0.3.0"
  #source = "./terraform-vault-terraform-cloud-jwt-auth"

  terraform = {
    org   = "fancycorp"
    alias = "LMHD"
  }

  vault = {
    addr      = data.tfe_outputs.vault_cluster.values.vault_public_endpoint_url
    namespace = data.tfe_outputs.vault_cluster.values.vault_namespace
    auth_path = "tfc/fancycorp"

    create_roles = false
  }

  roles = [
    {
      workspace_name = "vault-config-pki"
      token_policies = [
        vault_policy.admin.name
      ]
    },
  ]
}



module "tfc-auth-self" {
  source  = "hashi-strawb/terraform-cloud-jwt-auth/vault"
  version = ">= 0.2.1"
  #source = "./terraform-vault-terraform-cloud-jwt-auth"

  terraform = {
    org = "fancycorp"
  }

  vault = {
    addr      = data.tfe_outputs.vault_cluster.values.vault_public_endpoint_url
    namespace = data.tfe_outputs.vault_cluster.values.vault_namespace
    auth_path = "tfc/fancycorp-bootstrap" # can't have two separate JWT auth mounts
  }

  roles = [
    # give this workspace itself some dynamic creds
    # (if present, we'd like to use these instead of the admin token)
    {
      workspace_name = terraform.workspace
      token_policies = [
        # use a policy we are not managing ourselves, to avoid a race condition
        "hcp-root"
      ]
    }
  ]
}





//
// Protector for downstream workspace: destroy downstream before destroying this
//




# TODO: Parameterise which downstream workspaces we configure with a TF Var
# (e.g. sometimes we may not need to set up the azure secrets engine)

data "tfe_workspace" "downstream" {
  for_each = toset([
    "vault-config",
    "vault-config-aws",
    "vault-config-pki",
  ])

  name = each.key
}

resource "tfe_workspace_run" "downstream" {
  for_each = data.tfe_workspace.downstream

  workspace_id = each.value.id

  # We need to run the downstream destroys before we can delete any of these
  depends_on = [
    # downstream workspaces need auth
    module.tfc-auth,

    # this workspace needs JWT auth too
    tfe_variable.vault_auth_method,
    module.tfc-auth-self,
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

