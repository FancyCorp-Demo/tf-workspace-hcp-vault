resource "time_rotating" "admin_password" {
  rotation_days = 7
}

resource "random_pet" "admin_password" {
  length    = 5
  separator = " "

  lifecycle {
    replace_triggered_by = [time_rotating.admin_password]
  }
}


resource "vault_auth_backend" "userpass" {
  type = "userpass"

  tune {
    listing_visibility = "unauth"

    default_lease_ttl = "12h"
  }
}

resource "vault_generic_endpoint" "admin" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/admin"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "policies": ["admin", "noexist"],
  "password": "${random_pet.admin_password.id}"
}
EOT
}

output "admin_password" {
  value = random_pet.admin_password.id
}
