# Azure Tutorial

https://developer.hashicorp.com/vault/tutorials/secrets-management/azure-secrets


Configured with:
https://app.terraform.io/app/fancycorp/workspaces/vault-config

Useful workspace outputs:
* azure_application
  * Azure AD App Registration

* azure_resource_group
  * the resource group our role grants access to

* azure_graph_explorer_service_principal_owned_objects
  * Azure Graph API URL to list AAD SPs created by Vault


# TODO
TFC Workspace has permissions to view this AD group here
but not yet permissions to fully manage it.
Get it working, then configure this permission w/ TF



# Requesting Creds

```
vault read azure/creds/edu-app
```

## List Leases in Vault

List all leases:

```
vault list sys/leases/lookup/azure/creds/edu-app/
```

Lookup a specific lease:

```
vault write sys/leases/lookup lease_id=azure/creds/edu-app/auHd1LPWrpviBQFWEAak8nXG.vVZfW
```
