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

output "azure_resource_group_role_assignments" {
  value = "https://portal.azure.com/#@azure.hashicorptest.com/resource/${azurerm_resource_group.rg.id}/users"
}
