
# As a test, lookup self

data "vault_generic_secret" "lookup_self" {
  path = "auth/token/lookup-self"
}

output "self" {
  value = nonsensitive(data.vault_generic_secret.lookup_self.data)
}
