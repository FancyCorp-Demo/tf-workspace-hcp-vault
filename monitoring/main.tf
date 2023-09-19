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
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.45.0" # for tfe_workspace_run
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
    hcp-org-id     = var.hcp_org_id
    hcp-project-id = var.hcp_project_id
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

resource "aws_iam_access_key" "hcp_user" {
  user = aws_iam_user.hcp_user.name
}

#
# Kick off another Apply on the cluster workspace, to add the Cloudwatch monitoring
# (this may not work, as our monitoring workspace might not have output yet)
#

provider "tfe" {
  organization = "fancycorp"
}

data "tfe_workspace" "downstream" {
  for_each = toset([
    "vault"
  ])

  name = each.key
}
resource "tfe_workspace_run" "downstream" {
  for_each = data.tfe_workspace.downstream

  workspace_id = each.value.id

  depends_on = [
    aws_iam_access_key.hcp_user
  ]

  apply {
    manual_confirm = false # Let TF confirm this itself
    wait_for_run   = false # Fire-and-Forget
  }
}
