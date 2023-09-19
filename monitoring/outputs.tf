output "creds" {
  value     = aws_iam_access_key.hcp_user
  sensitive = true
}

/*
  "creds" = {
    "create_date" = "2023-09-19T10:54:34Z"
    "encrypted_secret" = null
    "encrypted_ses_smtp_password_v4" = null
    "id" = "REDACTED"
    "key_fingerprint" = null
    "pgp_key" = null
    "secret" = "REDACTED"
    "ses_smtp_password_v4" = "REDACTED"
    "status" = "Active"
    "user" = "demo-lucy.davinhart@hashicorp.com-vault-monitoring"
  }
*/
