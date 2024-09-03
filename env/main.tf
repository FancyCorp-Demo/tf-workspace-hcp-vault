terraform {
  required_providers {
    environment = {
      source  = "EppO/environment"
      version = "1.3.6"
    }
  }
}

provider "environment" {}

data "environment_variables" "all" {}

output "env" {
  value = data.environment_variables.all
}
