
data "tfe_variables" "imports" {
  workspace_id = data.tfe_workspace_ids.all.ids["vault-config-pki"]
}

locals {
  vars_by_name = { for v in data.tfe_variables.imports.variables : v.name => v.id }
}


import {
  to = module.tfc-auth-lmhd.tfe_variable.tfc_workspace_tfc_vault_addr["vault-config-pki"]
  id = "fancycorp/vault-config-pki/${local.vars_by_name["TFC_VAULT_ADDR_LMHD"]}"
}

import {
  to = module.tfc-auth-lmhd.tfe_variable.tfc_workspace_tfc_vault_namespace["vault-config-pki"]
  id = "fancycorp/vault-config-pki/${local.vars_by_name["TFC_VAULT_NAMESPACE_LMHD"]}"
}

import {
  to = module.tfc-auth-lmhd.tfe_variable.tfc_workspace_vault_auth_path["vault-config-pki"]
  id = "fancycorp/vault-config-pki/${local.vars_by_name["TFC_VAULT_AUTH_PATH_LMHD"]}"
}

import {
  to = module.tfc-auth-lmhd.tfe_variable.tfc_workspace_vault_provider_auth["vault-config-pki"]
  id = "fancycorp/vault-config-pki/${local.vars_by_name["TFC_VAULT_PROVIDER_AUTH_LMHD"]}"
}

import {
  to = module.tfc-auth-lmhd.tfe_variable.tfc_workspace_vault_run_role["vault-config-pki"]
  id = "fancycorp/vault-config-pki/${local.vars_by_name["TFC_VAULT_RUN_ROLE_LMHD"]}"
}

