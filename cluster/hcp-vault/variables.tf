variable "name" {
  type    = string
  default = "london"
}

variable "cloud" {
  type    = string
  default = "azure"
}

variable "region" {
  type    = string
  default = "eu-west-2"
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
