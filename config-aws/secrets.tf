
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

  # Because this is generated by TF, the creds will only last as long as the TF plan/apply
  #
  # Not using a vault_aws_access_credentials, because TF will try to do some validation on the creds...
  # which is nominally a good thing, but in this case it doesn't have the permissions it needs to do so
  data "vault_generic_secret" "creds" {
    path = "${vault_aws_secret_backend.aws.path}/creds/${vault_aws_secret_backend_role.test.name}"
  }

  assert {
    # Does the thing we got from Vault contain an "access_key" attribute?
    # If so... good enough for now to say we successfully got AWS creds
    #
    # Validated by disabling the IAM User's Access Key and running the health check again
    # (at which point, the check failed)
    condition     = can(data.vault_generic_secret.creds.data["access_key"])
    error_message = "${vault_aws_secret_backend.aws.path}/creds/${vault_aws_secret_backend_role.test.name} did not return AWS creds"
  }
}