
output "vault_public_endpoint_url" {
  value = hcp_vault_cluster.this.vault_public_endpoint_url
}

output "vault_cluster_id" {
  value = hcp_vault_cluster.this.cluster_id
}

output "vault_private_endpoint_url" {
  value = hcp_vault_cluster.this.vault_private_endpoint_url
}

output "vault_namespace" {
  value = hcp_vault_cluster.this.namespace
}

output "vault_admin_token" {
  value = hcp_vault_cluster_admin_token.terraform.token
}
