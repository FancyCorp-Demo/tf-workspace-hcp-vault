terraform {
  cloud {
    organization = "fancycorp"


    workspaces {
      name = "vault-config-aws"
    }
  }

  # Minimum provider version for OIDC auth
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }

  }
}

#
# AWS Config
#

# Based on:
#   https://github.com/hashicorp/hc-sec-demos/blob/main/demos/vault/aws_secrets_engine/
#   https://github.com/hashicorp/hc-sec-demos/blob/main/demos/vault/aws_auth_method/
#
# This means... if you're not a HashiCorp employee, don't use this. It won't work for you

provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      Name      = "HCP Vault Monitoring"
      Owner     = "lucy.davinhart@hashicorp.com"
      Purpose   = "TFC"
      TTL       = "Ephemeral Workspace"
      Terraform = "true"
      Source    = "https://github.com/FancyCorp-Demo/tf-workspace-hcp-vault/tree/main/config-aws/"
      Workspace = terraform.workspace
    }
  }
}
data "aws_caller_identity" "current" {}

variable "my_email" {
  default = "lucy.davinhart@hashicorp.com"
}

data "aws_region" "current" {}


# Vault Mount AWS Config Setup

data "aws_iam_policy" "demo_user_permissions_boundary" {
  name = "DemoUser"
}

resource "aws_iam_user" "vault_mount_user" {
  name                 = "demo-${var.my_email}-vault"
  permissions_boundary = data.aws_iam_policy.demo_user_permissions_boundary.arn
  force_destroy        = true
}

# Permissions boundary, required for SecOps
resource "aws_iam_user_policy_attachment" "vault_mount_user" {
  user       = aws_iam_user.vault_mount_user.name
  policy_arn = data.aws_iam_policy.demo_user_permissions_boundary.arn
}


# TODO: can we do something clever like... only create one if none exists?
# Or do we have to set a "create_access_key" variable on the workspace?
# And even then... we'd need to conditionally _not_ set
resource "aws_iam_access_key" "vault_mount_user" {

  # ensure that the policy attachment cannot be deleted without first deleting the access key
  # (which in turn cannot be deleted before deleting the Vault mount)
  #
  # This ensures that when deleting the secret backend, Vault still has permissions required to revoke creds
  depends_on = [aws_iam_user_policy_attachment.vault_mount_user]

  user = aws_iam_user.vault_mount_user.name
}
