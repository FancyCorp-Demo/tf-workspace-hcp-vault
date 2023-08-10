
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

resource "aws_iam_user" "hcp_user" {
  name                 = "demo-${var.my_email}-vault-monitoring"
  permissions_boundary = data.aws_iam_policy.demo_user_permissions_boundary.arn
  force_destroy        = true
}

# Permissions boundary, required for SecOps
resource "aws_iam_user_policy_attachment" "hcp_user" {
  user       = aws_iam_user.hcp_user.name
  policy_arn = data.aws_iam_policy.demo_user_permissions_boundary.arn
}



# TODO: policies for metrics and audits
# https://developer.hashicorp.com/vault/tutorials/cloud-monitoring/vault-audit-log-cloudwatch
# https://developer.hashicorp.com/vault/tutorials/cloud-monitoring/vault-metrics-cloudwatch
