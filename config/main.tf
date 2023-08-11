terraform {
  cloud {
    organization = "fancycorp"


    workspaces {
      name = "vault-config"
    }
  }
}
