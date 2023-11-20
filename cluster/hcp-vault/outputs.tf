
output "vault_public_endpoint_url" {
  value = module.hcp-vault-kerim.hcp_vault_cluster.vault_public_endpoint_url
}

output "vault_cluster_id" {
  value = module.hcp-vault-kerim.hcp_vault_cluster.cluster_id
}

output "vault_private_endpoint_url" {
  value = module.hcp-vault-kerim.hcp_vault_cluster.vault_private_endpoint_url
}

output "vault_namespace" {
  value = module.hcp-vault-kerim.hcp_vault_cluster.namespace
}

output "vault_admin_token" {
  value = hcp_vault_cluster_admin_token.terraform.token
}
