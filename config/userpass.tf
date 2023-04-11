resource "random_pet" "admin_password" {
  length    = 5
  separator = " "
}


resource "vault_auth_backend" "userpass" {
  type = "userpass"

  tune {
    listing_visibility = "unauth"
  }
}

resource "vault_generic_endpoint" "admin" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/admin"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "policies": ["admin"],
  "password": "${random_pet.admin_password.id}"
}
EOT
}
