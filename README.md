# TF Workspaces to provision an HCP Vault, and some config

There's probably an easier way to set this up, but this kinda works

Directories:
* `cluster` - creates the HCP Vault cluster (in AWS by default. also creates an admin token to be used by...
* `bootstrap` - sets up JWT Auth in Vault, using TFC Dynamic Creds. these are then used by...
* `config` - does the rest of the setup. technically this could be done in the same workspace as `bootstrap`, but I wanted to use this as an example of TFC Dynamic Creds. in this case, this also includes creating an AWS Secrets engine (which requires some additional resources in AWS)

`cluster` triggers a Terraform Apply on `bootstrap`, making use of Workspace Run Triggers.
(`bootstrap` does the same for `config`)

That handles the "When X is finished applying, start applying Y"

The missing step that Run Triggers can't help with is ensuring that these workspaces are all destroyed in the right order.

i.e. don't try to destroy the Vault cluster until the config has been successfully deleted first.
For that part, I'm making use of the Multispace provider, so that when I destroy `cluster` it first triggers a destroy on `boostrap`, which first triggers a destroy on `config`
