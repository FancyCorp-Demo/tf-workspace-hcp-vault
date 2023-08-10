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

# Based on https://github.com/hashicorp/hc-sec-demos/blob/main/demos/vault/aws_secrets_engine/aws.tf
# This means... if you're not a HashiCorp employee, don't use this. It won't work for you

provider "aws" {
  region = "eu-west-2"
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
  name                 = "demo-${var.my_email}"
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
  user = aws_iam_user.vault_mount_user.name
}


#
# Vault Config
#


locals {
  username_template = <<EOT
{{ if (eq .Type "STS") }}
	{{ printf "${aws_iam_user.vault_mount_user.name}-%s-%s" (random 20) (unix_time) | truncate 32 }}
{{ else }}
	{{ printf "${aws_iam_user.vault_mount_user.name}-vault-%s-%s" (unix_time) (random 20) | truncate 60 }}
{{ end }}
EOT

  # Known good config
  #    {{ printf "${aws_iam_user.vault_mount_user.name}-vault-%s-%s" (unix_time) (random 20) | truncate 60 }}
  #
  # Template from https://developer.hashicorp.com/vault/api-docs/secret/aws#username_template
  #    {{ printf "vault-%s-%s-%s" (printf "%s-%s" (.DisplayName) (.PolicyName) | truncate 42) (unix_time) (random 20) | truncate 64 }}
  # I can't get that to work, so... Known Good is fine for now

  username_template_without_whitespace = replace(
    replace(
      local.username_template,
      "\n", ""
    ),
    "\t", ""
  )
}

resource "vault_aws_secret_backend" "aws" {
  path = "aws/hashicorp/sandbox"

  access_key = aws_iam_access_key.vault_mount_user.id
  secret_key = aws_iam_access_key.vault_mount_user.secret

  username_template = local.username_template_without_whitespace

  # Ensures that usernames are prefixed with the name of the main Vault IAM user
  lifecycle {
    # These will be updated almost immediately by rotate-root
    ignore_changes = [
      access_key,
      secret_key,
    ]
  }
}


data "aws_iam_policy_document" "describe_regions" {
  statement {
    sid       = "VaultDemoUserDescribeEC2Regions"
    actions   = ["ec2:DescribeRegions"]
    resources = ["*"]
  }
}

resource "vault_aws_secret_backend_role" "test" {
  backend                  = vault_aws_secret_backend.aws.path
  name                     = "test"
  credential_type          = "iam_user"
  permissions_boundary_arn = data.aws_iam_policy.demo_user_permissions_boundary.arn
  policy_document          = data.aws_iam_policy_document.describe_regions.json
}


data "aws_iam_policy_document" "admin" {
  statement {
    sid       = "Admin"
    actions   = ["*"]
    resources = ["*"]
  }
}
resource "vault_aws_secret_backend_role" "developers" {
  backend         = vault_aws_secret_backend.aws.path
  name            = "developers"
  credential_type = "iam_user"

  # Full admin access...
  policy_document = data.aws_iam_policy_document.admin.json
  # But constrained by the Permissions Boundary
  permissions_boundary_arn = data.aws_iam_policy.demo_user_permissions_boundary.arn
}







// Rotate root immediately, so only Vault knows it
/*
resource "time_rotating" "aws" {
  rotation_days = 30
}
resource "vault_generic_endpoint" "rotate-root" {
  path           = "${vault_aws_secret_backend.aws.path}/config/rotate-root"
  disable_read   = true
  disable_delete = true

  # The API endpoint expects no parameters
  # https://www.vaultproject.io/api/secret/aws#rotate-root-iam-credentials
  # But if we send anything we like, Vault will ignore it
  # Thus, we send the time rotation
  data_json = <<EOT
{
  "rotate": "${time_rotating.aws.id}"
}
EOT
}
*/


# TODO: Fix this issue. Currently, we have:
#
# First TF Apply..
# aws_iam_access_key.vault-aws-secrets creates some IAM creds
#   at this point, the IAM user has a single set of Access Keys
# vault_generic_endpoint.rotate-root rotates those creds
#   at this point, the IAM user has a single (different) set of Access Keys
#   AKIAYG76LF7ZWO3QZM7Y
#
# Second TF Apply...
# TF detects that aws_iam_access_key.vault-aws-secrets no longer exists, and recreates it
#   at this point, the IAM user has two sets of Access Keys (which would block the next rotate-root)
#   AKIAYG76LF7ZUHNKFGNY is the new one
#
# TF Destroy...
# TF destroys the IAM crds that it created
#   destroy fails, because AKIAYG76LF7ZWO3QZM7Y still exists
#   (i.e. the one created by TF 

# So what we need is:
#   Some way for the for the workspace to avoid recreating the creds
#     e.g. to add a TF Var to say whether or not to create aws_iam_access_key.vault-aws-secrets
#     or use a data source to check if one already exists
#
#   Force Destroy the IAM User
#     i.e. https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user#force_destroy
#     though this does not solve the problem that the next rotate-root will fail
#
#   Or...
#     just make the time_rotating rotate-root optional behaviour






# TODO: Validate, by generating some creds

