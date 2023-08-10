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


#
# Vault Config
#


locals {
  username_template = <<EOT
{{ if (eq .Type "STS") }}
	{{ printf "${aws_iam_user.vault_mount_user.name}-%s-%s" (random 20) (unix_time) | truncate 32 }}
{{ else }}
	{{ printf "${aws_iam_user.vault_mount_user.name}-%s-%s" (unix_time) (random 20) | truncate 60 }}
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
}
// In a real production use-case, we'd want to rotate-root ASAP
// probably doable with TF somehow, without causing feedback loops... but not important for my demos



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




# Validate the secret engine works by generating some creds
check "test_creds" {
  data "vault_aws_access_credentials" "creds" {
    backend = vault_aws_secret_backend.aws.path
    role    = vault_aws_secret_backend_role.test.name
  }

  assert {
    condition     = data.vault_aws_access_credentials.creds.access_key != ""
    error_message = "${vault_aws_secret_backend.aws.path}/creds/${vault_aws_secret_backend_role.test.name} did not return AWS creds"
  }
}
