terraform {
  cloud {
    organization = "fancycorp"


    workspaces {
      name = "vault-config-pki"
    }
  }
}



# https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/vault-configuration#specifying-multiple-configurations

variable "tfc_vault_dynamic_credentials" {
  description = "Object containing Vault dynamic credentials configuration"
  type = object({
    default = object({
      token_filename = string
      address        = string
      namespace      = string
      ca_cert_file   = string
    })
    aliases = map(object({
      token_filename = string
      address        = string
      namespace      = string
      ca_cert_file   = string
    }))
  })
}


provider "vault" {
  // skip_child_token must be explicitly set to true as HCP Terraform manages the token lifecycle
  skip_child_token = true
  address          = var.tfc_vault_dynamic_credentials.default.address
  namespace        = var.tfc_vault_dynamic_credentials.default.namespace

  auth_login_token_file {
    filename = var.tfc_vault_dynamic_credentials.default.token_filename
  }
}

locals {
  vault_addr      = var.tfc_vault_dynamic_credentials.default.address
  vault_namespace = var.tfc_vault_dynamic_credentials.default.namespace
}


provider "vault" {
  // skip_child_token must be explicitly set to true as HCP Terraform manages the token lifecycle
  skip_child_token = true
  alias            = "LMHD"
  address          = var.tfc_vault_dynamic_credentials.aliases["LMHD"].address
  namespace        = var.tfc_vault_dynamic_credentials.aliases["LMHD"].namespace

  auth_login_token_file {
    filename = var.tfc_vault_dynamic_credentials.aliases["LMHD"].token_filename
  }
}



#
# Intermediary CA
#

resource "vault_mount" "pki_inter" {
  path = "pki/inter"
  type = "pki"

  # 1 day
  default_lease_ttl_seconds = 60 * 60 * 24

  # 1 year
  max_lease_ttl_seconds = 60 * 60 * 24 * 365
}

resource "vault_pki_secret_backend_config_urls" "pki_inter_config_urls" {
  backend                 = vault_mount.pki_inter.path
  issuing_certificates    = ["${local.vault_addr}/v1/${local.vault_namespace}/${vault_mount.pki_inter.path}/ca"]
  crl_distribution_points = ["${local.vault_addr}/v1/${local.vault_namespace}/${vault_mount.pki_inter.path}/crl"]
}


#
# Generate Inter CSR
#

resource "time_rotating" "pki_inter" {
  rotation_months = 4
}

resource "vault_pki_secret_backend_intermediate_cert_request" "pki_inter" {
  depends_on = [vault_mount.pki_inter]

  backend = vault_mount.pki_inter.path

  type        = "internal"
  common_name = "FancyCorp Intermediary CA (${time_rotating.pki_inter.id})"
}



#
# Root signs Inter
#

resource "vault_pki_secret_backend_root_sign_intermediate" "pki_root_inter" {
  depends_on = [vault_pki_secret_backend_intermediate_cert_request.pki_inter]

  backend = "pki/root"

  csr         = vault_pki_secret_backend_intermediate_cert_request.pki_inter.csr
  common_name = "FancyCorp Intermediary CA"
  format      = "pem_bundle"
  ttl         = 60 * 60 * 24 * 365

  provider = vault.LMHD
}


# Set Inter CA

resource "vault_pki_secret_backend_intermediate_set_signed" "pki_inter" {
  backend = vault_mount.pki_inter.path

  certificate = <<-EOF
${vault_pki_secret_backend_root_sign_intermediate.pki_root_inter.certificate}
${vault_pki_secret_backend_root_sign_intermediate.pki_root_inter.issuing_ca}
EOF
}

data "tls_certificate" "pki_inter" {
  content = vault_pki_secret_backend_root_sign_intermediate.pki_root_inter.certificate
}


# Ensure that the default issuer is set to the latest issuer
resource "vault_pki_secret_backend_config_issuers" "pki_inter" {
  backend = vault_mount.pki_inter.path

  default = vault_pki_secret_backend_intermediate_set_signed.pki_inter.imported_issuers[0]
}


# TODO: CV Check, expiry is sufficiently in the future
# (for this, expiry is more than today is fine... but we do next month to give buffer room)


# Autotidy

resource "vault_generic_endpoint" "pki_inter-auto-tidy" {
  path = "${vault_mount.pki_inter.path}/config/auto-tidy"

  disable_delete = true

  data_json = <<EOT
{
  "acme_account_safety_buffer": 1,
  "enabled": true,
  "interval_duration": 43200,
  "issuer_safety_buffer": 10368000,
  "maintain_stored_certificate_counts": false,
  "pause_duration": "0s",
  "publish_stored_certificate_count_metrics": false,
  "revocation_queue_safety_buffer": 172800,
  "safety_buffer": 259200,
  "tidy_acme": false,
  "tidy_cert_metadata": false,
  "tidy_cert_store": true,
  "tidy_cross_cluster_revoked_certs": true,
  "tidy_expired_issuers": true,
  "tidy_move_legacy_ca_bundle": true,
  "tidy_revocation_queue": true,
  "tidy_revoked_cert_issuer_associations": true,
  "tidy_revoked_certs": true
}
EOT
}
