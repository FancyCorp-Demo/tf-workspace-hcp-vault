
output "vault_public_endpoint_url" {
  value = module.hcp-vault.vault_public_endpoint_url
}

output "vault_cluster_id" {
  value = module.hcp-vault.vault_cluster_id
}

output "vault_private_endpoint_url" {
  value = module.hcp-vault.vault_private_endpoint_url
}

output "vault_namespace" {
  value = module.hcp-vault.vault_namespace
}

output "vault_admin_token" {
  value     = module.hcp-vault.vault_admin_token
  sensitive = true
}
