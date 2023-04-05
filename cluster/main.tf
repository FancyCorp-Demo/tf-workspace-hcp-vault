
terraform {
  cloud {
    organization = "fancycorp"

    workspaces {
      name = "vault"
    }
  }
}

terraform {
  required_providers {
    hcp = {
      source = "hashicorp/hcp"
    }
  }
}


//
// HCP Vault Cluster
//

provider "hcp" {}

module "hcp-vault" {
  source = "./hcp-vault"

  #  name       = "azure-london"
  #  cloud      = "azure"
  #  region     = "uksouth"

  name   = "aws-london"
  cloud  = "aws"
  region = "eu-west-2"

  cidr_block = "10.0.0.0/24"

  public_endpoint = true
}

