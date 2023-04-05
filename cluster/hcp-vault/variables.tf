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
