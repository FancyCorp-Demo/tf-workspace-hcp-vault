terraform {
  cloud {
    organization = "fancycorp"


    workspaces {
      name = "vault-config-azure"
    }
  }
}

// Nothing for now, but make sure this is a valid TF Workspace
