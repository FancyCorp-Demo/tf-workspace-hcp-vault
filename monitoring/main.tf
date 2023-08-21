terraform {
  cloud {
    organization = "fancycorp"


    workspaces {
      name = "vault-monitoring"
    }
  }

  # Minimum provider version for OIDC auth
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

resource "aws_iam_user" "hcp_user" {
  name                 = "demo-${var.my_email}-vault-monitoring"
  permissions_boundary = data.aws_iam_policy.demo_user_permissions_boundary.arn
  force_destroy        = true


  tags = {
    # TODO: Get HCP details from variables
    hcp-org-id     = "ffa120a5-d7b1-4b9c-be17-33a71e45f43f"
    hcp-project-id = "d6c96d2b-616b-4cb8-b78c-9e17a78c2167"
  }
}

# TODO: can we create this without the DemoUser policy (and just have it as a PB?)
# Permissions boundary, required for SecOps
#resource "aws_iam_user_policy_attachment" "hcp_user" {
#  user       = aws_iam_user.hcp_user.name
#  policy_arn = data.aws_iam_policy.demo_user_permissions_boundary.arn
#}



# Policies for metrics and audits
# https://developer.hashicorp.com/vault/tutorials/cloud-monitoring/vault-audit-log-cloudwatch
# https://developer.hashicorp.com/vault/tutorials/cloud-monitoring/vault-metrics-cloudwatch


data "aws_iam_policy_document" "hcp_cloudwatch_metrics" {
  statement {
    sid = "HCPMetricStreaming"
    actions = [
      "cloudwatch:ListMetrics",
      "cloudwatch:ListMetricStreams",
      "cloudwatch:ListTagsForResource",
      "cloudwatch:PutMetricData",
      "cloudwatch:PutMetricStream",
      "cloudwatch:TagResource"
    ]

    # TODO: be more specific
    resources = ["*"]
  }
}
resource "aws_iam_policy" "metrics" {
  name        = "hcp-metrics"
  description = "https://developer.hashicorp.com/vault/tutorials/cloud-monitoring/vault-metrics-cloudwatch"
  policy      = data.aws_iam_policy_document.hcp_cloudwatch_metrics.json
}
resource "aws_iam_policy_attachment" "metrics" {
  name       = "metrics"
  users      = [aws_iam_user.hcp_user.name]
  policy_arn = aws_iam_policy.metrics.arn
}

data "aws_iam_policy_document" "hcp_cloudwatch_logs" {
  statement {
    sid = "HCPLogStreaming"
    actions = [
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:TagLogGroup"
    ]

    # TODO: be more specific
    resources = ["*"]
  }
}
resource "aws_iam_policy" "audit" {
  name        = "hcp-audit"
  description = "https://developer.hashicorp.com/vault/tutorials/cloud-monitoring/vault-audit-log-cloudwatch"
  policy      = data.aws_iam_policy_document.hcp_cloudwatch_logs.json
}
resource "aws_iam_policy_attachment" "audit" {
  name       = "audit"
  users      = [aws_iam_user.hcp_user.name]
  policy_arn = aws_iam_policy.audit.arn
}





# TODO: Create creds
# Holding off on this for now, as we still have manual steps anyway...
# (meaning I need direct acccess to these creds to do the config)

# TODO: Configure HCP
# Currently not possible:
# https://registry.terraform.io/providers/hashicorp/hcp/latest/docs/resources/vault_cluster
# does not accept cloudwatch config yet... and is also nested config for the hcp_vault_cluster resource
