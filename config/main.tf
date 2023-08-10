terraform {
  cloud {
    organization = "fancycorp"


    workspaces {
      name = "vault-config"
    }
  }

  # Minimum provider version for OIDC auth
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.29.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.25.0"
    }

  }
}
