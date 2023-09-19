output "creds" {
  value     = aws_iam_access_key.hcp_user
  sensitive = true
}
