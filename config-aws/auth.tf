
resource "vault_auth_backend" "aws" {
  type = "aws"
}

resource "vault_aws_auth_backend_client" "client" {
  backend    = vault_auth_backend.aws.path
  access_key = aws_iam_access_key.vault_mount_user.id
  secret_key = aws_iam_access_key.vault_mount_user.secret
}

resource "vault_aws_auth_backend_config_identity" "identity_config" {
  backend   = vault_auth_backend.aws.path
  iam_alias = "role_id"
  iam_metadata = [
    "account_id",
    "auth_type",
    "canonical_arn",
    "client_arn",
  "client_user_id"]
}

resource "vault_aws_auth_backend_role" "role" {
  backend   = vault_auth_backend.aws.path
  role      = "test-role"
  auth_type = "iam"

  # Anything in my AWS Account
  bound_iam_principal_arns = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:*"
  ]

  token_ttl      = 60
  token_max_ttl  = 120
  token_policies = ["kv"]
}

resource "vault_mount" "kvv1" {
  path    = "kvv1"
  type    = "kv"
  options = { version = "1" }
}

resource "vault_kv_secret" "secret" {
  path = "${vault_mount.kvv1.path}/secrets"
  data_json = jsonencode(
    {
      zip = "zap",
      foo = "bar"
    }
  )
}

resource "vault_policy" "kv_policy" {
  name = "kv"

  policy = <<EOT
path "kvv1/*" {
  capabilities = ["read"]
}
EOT
}




#
# IAM Instance Profile to add to EC2 instances
#

resource "aws_iam_instance_profile" "test_profile" {
  name = "vault-auth"
  role = aws_iam_role.role.name
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "role" {
  name               = "vault-auth"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
