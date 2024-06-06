variable "name" {
  type    = string
  default = "london"
}

variable "cloud" {
  type    = string
  default = "azure"
  // TODO: Validate that this is either aws or azure
}

variable "region" {
  type    = string
  default = "uksouth"
  // TODO: Validate that the specified region makes sense for the specified cloud
}

variable "cidr_block" {
  type    = string
  default = "10.0.0.0/24"
}

variable "tier" {
  type    = string
  default = "starter_small"
}

variable "public_endpoint" {
  type    = bool
  default = false
}


variable "cloudwatch_creds" {
  type = object({
    key    = string
    secret = string
    region = optional(string, "eu-west-2")
  })
  default = null
}

variable "min_vault_version" {
  type    = string
  default = null
}
