provider "azurerm" {
  features {}
}


# Create a resource group, for us to add Vault-generated permissions to

resource "azurerm_resource_group" "rg" {
  name     = "strawb-vault-demo"
  location = "uksouth"

  tags = {
    Name        = "StrawbTest"
    Owner       = "lucy.davinhart@hashicorp.com"
    Purpose     = "Azure Secrets, based on https://developer.hashicorp.com/vault/tutorials/secrets-management/azure-secrets"
    TTL         = "24h"
    Terraform   = "true"
    Source      = "https://github.com/FancyCorp-Demo/tf-workspace-hcp-vault/tree/main/config/"
    DoNotDelete = "True"
    Workspace   = terraform.workspace
  }
}

# Here's our RG in the Azure portal
output "azure_resource_group" {
  value = "https://portal.azure.com/#@azure.hashicorptest.com/resource${azurerm_resource_group.rg.id}/overview"
}



#
# AAD Application and Service Principal
#

# Originally created based on tutorial https://developer.hashicorp.com/vault/tutorials/secrets-management/azure-secrets
# then imported into TF
data "azuread_client_config" "current" {}

/*
data "azuread_user" "lucy" {
  user_principal_name = "lucy.davinhart_hashicorp.com#EXT#@terraformhashicorp.onmicrosoft.com"
}
*/


data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  application_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
}

resource "azuread_application" "vault_application" {
  display_name = "strawb-vault-demo"
  owners = [
    # Owned by the workspace...
    data.azuread_client_config.current.object_id,

    # But also owned by me, so I can easily find it
    #data.azuread_user.lucy.id,
  ]

  required_resource_access {
    resource_app_id = data.azuread_service_principal.msgraph.application_id

    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.OwnedBy"]
      type = "Role"
    }
  }
}

output "azure_application" {
  value = "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/${azuread_application.vault_application.application_id}"
}



# Creates a service principal associated with the previously created
# application registration.
resource "azuread_service_principal" "vault_service_principal" {
  application_id = azuread_application.vault_application.application_id

  owners = [
    # Owned by the workspace...
    data.azuread_client_config.current.object_id,

    # But also owned by me, so I can easily find it
    # data.azuread_user.lucy.id,
  ]
}
output "azure_graph_explorer_service_principal_owned_objects" {
  value = join("",
    [
      "https://developer.microsoft.com/en-us/graph/graph-explorer?request=servicePrincipals%2F",
      azuread_service_principal.vault_service_principal.id,
      "%2FownedObjects%3F%24select%3Did%2CappId%2CdisplayName%2CcreatedDateTime&method=GET&version=v1.0"
    ]
  )
}




#
# Azure AD Permissions
#

resource "azuread_app_role_assignment" "vault_application" {
  # All permissions for full usage are mentioned here:
  # https://developer.hashicorp.com/vault/tutorials/secrets-management/azure-secrets
  # https://developer.hashicorp.com/vault/docs/secrets/azure#ms-graph-api-permissions
  # But I've found this one to be sufficient for my demo
  for_each = toset([
    "Application.ReadWrite.OwnedBy"
  ])

  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids[each.key]
  principal_object_id = azuread_service_principal.vault_service_principal.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id


  # We could also grant Delegated permissions
  # https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal_delegated_permission_grant
  # But those do not seem to be needed either
}



#
# Azure RM Permissions
#


# Creates a role assignment which controls the permissions the service
# principal has within the Azure subscription.
data "azurerm_subscription" "current" {}
resource "azurerm_role_assignment" "vault_role_assignment" {

  scope        = azurerm_resource_group.rg.id
  principal_id = azuread_service_principal.vault_service_principal.object_id

  # Owner, to have permissions to delegate permissions
  # Practically, this can be done with less permissions than "Owner"
  # but for the sake of a simple demo, this is fine.
  role_definition_name = "Owner"
}


resource "azuread_application_password" "vault_role_client_secret" {
  application_object_id = azuread_application.vault_application.object_id
  display_name          = "Vault Creds"

  depends_on = [
    azuread_app_role_assignment.vault_application,
    azurerm_role_assignment.vault_role_assignment,
  ]
  lifecycle {
    replace_triggered_by = [
      azuread_app_role_assignment.vault_application,
      azurerm_role_assignment.vault_role_assignment,
    ]
  }
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [azuread_application_password.vault_role_client_secret]
  lifecycle {
    replace_triggered_by = [azuread_application_password.vault_role_client_secret]
  }

  create_duration = "30s"
}




# https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/azure_secret_backend
resource "vault_azure_secret_backend" "azure" {
  # Wait some time between creation of the credentials and using them to configure Vault
  # as otherwise we get errors of the form:
  # AADSTS7000215: Invalid client secret provided. Ensure the secret being sent in the request is the client secret value, not the client secret ID, for a secret added to app
  depends_on = [time_sleep.wait_30_seconds]


  use_microsoft_graph_api = true
  subscription_id         = data.azurerm_subscription.current.subscription_id
  tenant_id               = data.azurerm_subscription.current.tenant_id
  client_id               = azuread_application.vault_application.application_id
  client_secret           = azuread_application_password.vault_role_client_secret.value
  environment             = "AzurePublicCloud"

  path = "azure"
}


# https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/azure_secret_backend_role
resource "vault_azure_secret_backend_role" "example" {
  backend = vault_azure_secret_backend.azure.path
  role    = "edu-app"
  ttl     = 300
  max_ttl = 3600

  azure_roles {
    role_name = "Contributor"
    scope     = azurerm_resource_group.rg.id
  }

  # Delete the AAD App immediately
  # https://developer.hashicorp.com/vault/docs/secrets/azure#permanently-delete-azure-objects
  # but not yet available in the provider
  #permanently_delete = true
}
