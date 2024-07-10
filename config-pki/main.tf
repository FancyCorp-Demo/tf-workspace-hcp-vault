terraform {
  cloud {
    organization = "fancycorp"


    workspaces {
      name = "vault-config-pki"
    }
  }
}



# https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/vault-configuration#specifying-multiple-configurations

variable "tfc_vault_dynamic_credentials" {
  description = "Object containing Vault dynamic credentials configuration"
  type = object({
    default = object({
      token_filename = string
      address        = string
      namespace      = string
      ca_cert_file   = string
    })
    aliases = map(object({
      token_filename = string
      address        = string
      namespace      = string
      ca_cert_file   = string
    }))
  })
}


provider "vault" {
  // skip_child_token must be explicitly set to true as HCP Terraform manages the token lifecycle
  skip_child_token = true
  address          = var.tfc_vault_dynamic_credentials.default.address
  namespace        = var.tfc_vault_dynamic_credentials.default.namespace

  auth_login_token_file {
    filename = var.tfc_vault_dynamic_credentials.default.token_filename
  }
}

data "vault_generic_secret" "lookup_self" {
  path = "auth/token/lookup-self"
}

output "lookup_self" {
  value = nonsensitive(data.vault_generic_secret.lookup_self.data_json)
}


provider "vault" {
  // skip_child_token must be explicitly set to true as HCP Terraform manages the token lifecycle
  skip_child_token = true
  alias            = "LMHD"
  address          = var.tfc_vault_dynamic_credentials.aliases["LMHD"].address
  namespace        = var.tfc_vault_dynamic_credentials.aliases["LMHD"].namespace

  auth_login_token_file {
    filename = var.tfc_vault_dynamic_credentials.aliases["LMHD"].token_filename
  }
}


data "vault_generic_secret" "lookup_self_alias" {
  path = "auth/token/lookup-self"
}

output "lookup_self_alias" {
  value = nonsensitive(data.vault_generic_secret.lookup_self_alias.data_json)
}
