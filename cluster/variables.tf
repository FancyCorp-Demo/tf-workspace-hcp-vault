variable "hcp_platform" {
  type    = string
  default = "aws"

  validation {
    condition     = contains(["aws", "azure"], var.hcp_platform)
    error_message = "Platform ${var.hcp_platform} not one of the allowed options: aws, azure"
  }
}

variable "hcp_region" {
  type    = string
  default = "eu-west-2"


  # TODO: Set allowed regions per platform
  # AWS: eu-west-1, eu-west-2
  # Azure: uksouth
}


variable "hcp_vault_cluster_name" {
  type    = string
  default = "aws-london"
}
