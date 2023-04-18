provider "aws" {
  region = "eu-west-2"
}
data "aws_caller_identity" "current" {}


resource "aws_iam_user" "vault-aws-secrets" {
  name = "aws-secrets"
  path = "/vault/"
}

data "aws_iam_policy_document" "vault-aws-secrets" {
  statement {
    effect = "Allow"
    actions = [
      "iam:AttachUserPolicy",
      "iam:CreateAccessKey",
      "iam:CreateUser",
      "iam:DeleteAccessKey",
      "iam:DeleteUser",
      "iam:DeleteUserPolicy",
      "iam:DetachUserPolicy",
      "iam:GetUser",
      "iam:ListAccessKeys",
      "iam:ListAttachedUserPolicies",
      "iam:ListGroupsForUser",
      "iam:ListUserPolicies",
      "iam:PutUserPolicy",
      "iam:AddUserToGroup",
      "iam:RemoveUserFromGroup"
    ]
    resources = [
      # Allow managing any users it creates...
      # As well as managing itself
      # TODO: Realistically, it should have fewer permissions here. i.e. to only allow rotating its own creds
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/vault-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/vault/*",
    ]
  }
}

resource "aws_iam_user_policy" "vault-aws-secrets" {
  name   = "vault-aws-secrets"
  user   = aws_iam_user.vault-aws-secrets.name
  policy = data.aws_iam_policy_document.vault-aws-secrets.json
}

resource "aws_iam_access_key" "vault-aws-secrets" {
  user = aws_iam_user.vault-aws-secrets.name
}

resource "vault_aws_secret_backend" "aws" {
  path = "aws/hashicorp/sandbox"

  access_key = aws_iam_access_key.vault-aws-secrets.id
  secret_key = aws_iam_access_key.vault-aws-secrets.secret

  lifecycle {
    # These will be updated almost immediately by rotate-root
    ignore_changes = [
      access_key,
      secret_key,
    ]
  }
}


// Rotate root immediately, so only Vault knows it
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


# TODO: Fix this issue. Currently, we have:
# * aws_iam_access_key.vault-aws-secrets creates some IAM creds
# * vault_generic_endpoint.rotate-root rotates those creds



resource "vault_aws_secret_backend_role" "test" {
  backend         = vault_aws_secret_backend.aws.path
  name            = "test"
  credential_type = "iam_user"

  user_path = "/vault/"

  policy_document = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:List*"
            ],
            "Resource": "*"
        }
    ]
}
EOT
}
