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
  value = "https://portal.azure.com/#/resource${azurerm_resource_group.rg.id}"
}



#
# AAD Application and Service Principal
#

# Originally created based on tutorial https://developer.hashicorp.com/vault/tutorials/secrets-management/azure-secrets
# then imported into TF
data "azuread_client_config" "current" {}
resource "azuread_application" "vault_application" {
  display_name = "strawb-vault-demo"
  #owners       = [data.azuread_client_config.current.object_id]
  owners = [
    "9368d8f2-1fcd-4e62-b950-8c19616924b4"
    # TODO: LD created by hand... for now, because we don't have permission to set to the thing above yet
    # Figure out permissions needed for this
    #
    # This is what we have for now, but it's insufficient
    #     https://portal.azure.com/#view/Microsoft_Azure_PIMCommon/UserRolesViewModelMenuBlade/~/members/roleObjectId/9360feb5-f418-4baa-8175-e2a00bac4301/roleId/9360feb5-f418-4baa-8175-e2a00bac4301/roleTemplateId/9360feb5-f418-4baa-8175-e2a00bac4301/roleName/Directory%20Writers/isRoleCustom~/false/resourceScopeId/%2F/resourceId/0e3e2e88-8caf-41ca-b4da-e3b33b6c52ec
    #
    # Maybe the required_resource_access stuff below is what needs to be added to the TFC role

  ]

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph


    # These permissions are much mroe than is actually required, but good enough for now
    resource_access {
      # ???
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }
    resource_access {
      # Read all groups  
      id   = "5f8c59db-677d-491f-a6b8-5f174b11ec1d"
      type = "Scope"
    }
    resource_access {
      # Read and write all groups  
      id   = "4e46008b-f24c-477d-8fff-7bb4ec7aafe0"
      type = "Scope"
    }
    resource_access {
      # Read directory data
      id   = "06da0dbc-49e2-44d2-8312-53f166ab848a"
      type = "Scope"
    }
    resource_access {
      # Read and write directory data
      id   = "c5366453-9fb0-48a5-a156-24f0c49a4b84"
      type = "Scope"
    }
    resource_access {
      # Access directory as the signed in user 
      id   = "0e263e50-5827-48a4-b97c-d940288653c7"
      type = "Scope"
    }
    resource_access {
      # ???
      id   = "c79f8feb-a9db-4090-85f9-90d820caa0eb"
      type = "Scope"
    }
    resource_access {
      # ???
      id   = "bdfbf15f-ee85-4955-8675-146e8e5296b5"
      type = "Scope"
    }
    resource_access {
      # ???
      id   = "bc024368-1153-4739-b217-4326f2e966d0"
      type = "Scope"
    }
    resource_access {
      # ???
      id   = "f81125ac-d3b7-4573-a3b2-7099cc39df9e"
      type = "Scope"
    }
    resource_access {
      # Read and write all groups
      id   = "62a82d76-70ea-41e2-9197-370581804d09"
      type = "Role"
    }
    resource_access {
      # Read all groups
      id   = "5b567255-7703-4780-807c-7be8301ae99b"
      type = "Role"
    }
    resource_access {
      # ???
      id   = "18a4783c-866b-4cc7-a460-3d5e5662c884"
      type = "Role"
    }
    resource_access {
      # ???
      id   = "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9"
      type = "Role"
    }
    resource_access {
      # Read directory data
      id   = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"
      type = "Role"
    }
    resource_access {
      # Read and write directory data
      id   = "19dbc75e-c2e2-444c-a770-ec69d8559fc7"
      type = "Role"
    }
    resource_access {
      # ???
      id   = "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"
      type = "Role"
    }
    resource_access {
      # ???
      id   = "98830695-27a2-44f7-8c18-0c3ebc9698f6"
      type = "Role"
    }
    resource_access {
      # ???
      id   = "dbaae8cf-10b5-4b86-a4a1-f871c94c6695"
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


# Creates a role assignment which controls the permissions the service
# principal has within the Azure subscription.
data "azurerm_subscription" "current" {}
resource "azurerm_role_assignment" "vault_role_assignment" {

  # TODO: move this to be scoped to the RG
  # TODO: make it a Contributor
  scope                = data.azurerm_subscription.current.id
  principal_id         = azuread_service_principal.vault_service_principal.object_id
  role_definition_name = "Owner"
}


resource "azuread_application_password" "vault_role_client_secret" {
  application_object_id = azuread_application.vault_application.object_id
  display_name          = "Vault Creds"
}


/*

# https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/azure_secret_backend
resource "vault_azure_secret_backend" "azure" {
  use_microsoft_graph_api = true
  subscription_id         = "11111111-2222-3333-4444-111111111111"
  tenant_id               = "11111111-2222-3333-4444-222222222222"
  client_id               = "11111111-2222-3333-4444-333333333333"
  client_secret           = "12345678901234567890"
  environment             = "AzurePublicCloud"

  path = "azure-2"
}


# https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/azure_secret_backend_role
resource "vault_azure_secret_backend_role" "generated_role" {
  backend                     = vault_azure_secret_backend.azure.path
  role                        = "generated_role"
  ttl                         = 300
  max_ttl                     = 600

  azure_roles {
    role_name = "Reader"
    scope =  "/subscriptions/${var.subscription_id}/resourceGroups/azure-vault-group"
  }
}
*/


