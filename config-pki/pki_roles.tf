
# List all YAML files in subdirectories of pki/
# each of these correspond to PKI Mounts in Vault
# e.g. pki/inter
locals {
  pki_role_files = fileset(path.module, "pki/*/*.yaml")
}

resource "vault_pki_secret_backend_role" "pki_roles" {
  # For each YAML file we found...
  for_each = local.pki_role_files

  # Use the "backend" key if specified
  # otherwise fall back to the directory name
  backend = lookup(
    yamldecode(file(each.key)),
    "backend",
    dirname(each.key)
  )

  # Use the "name" key if specified
  # otherwise fallback to filename, minus .yaml
  name = lookup(
    yamldecode(file(each.key)),
    "name",
    trimsuffix(basename(each.key), ".yaml")
  )

  # Other parameters, use defaults from
  # https://www.vaultproject.io/api/secret/pki#create-update-role
  # unless otherwise specified
  #
  # This list of parameters is short, as it only includes those we actually
  # make use of for now. It can expand as needed


  allow_any_name = lookup(
    yamldecode(file(each.key)),
    "allow_any_name",
    false
  )

  allow_bare_domains = lookup(
    yamldecode(file(each.key)),
    "allow_bare_domains",
    false
  )

  allow_ip_sans = lookup(
    yamldecode(file(each.key)),
    "allow_ip_sans",
    true
  )

  enforce_hostnames = lookup(
    yamldecode(file(each.key)),
    "enforce_hostnames",
    true
  )

  require_cn = lookup(
    yamldecode(file(each.key)),
    "require_cn",
    true
  )

  ou = lookup(
    yamldecode(file(each.key)),
    "ou",
    []
  )

  organization = lookup(
    yamldecode(file(each.key)),
    "organization",
    []
  )

  client_flag = lookup(
    yamldecode(file(each.key)),
    "client_flag",
    true
  )

  server_flag = lookup(
    yamldecode(file(each.key)),
    "server_flag",
    true
  )

  allowed_domains = lookup(
    yamldecode(file(each.key)),
    "allowed_domains",
    []
  )

  allow_localhost = lookup(
    yamldecode(file(each.key)),
    "allow_localhost",
    true
  )

  allow_subdomains = lookup(
    yamldecode(file(each.key)),
    "allow_subdomains",
    false
  )

  key_usage = lookup(
    yamldecode(file(each.key)),
    "key_usage",
    ["DigitalSignature", "KeyAgreement", "KeyEncipherment"]
  )

  ttl = lookup(
    yamldecode(file(each.key)),
    "ttl",
    ""
  )

  max_ttl = lookup(
    yamldecode(file(each.key)),
    "max_ttl",
    ""
  )
}

