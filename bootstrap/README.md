# bootstrap

Creates the always-on resources. **The SA runs it by hand once** (an account with Owner on the subscription); after that it hardly changes.

```bash
az login
cd bootstrap
cat > bootstrap.tfvars <<'T'        # *.tfvars files are gitignored
subscription_id     = "<subscription id>"
github_owner        = "<GitHub account>"
budget_alert_emails = ["<your email>"]
monthly_budget_usd  = <amount set by the PM>
budget_start_date   = "2026-11-01T00:00:00Z"
T
terraform init
terraform plan  -var-file=bootstrap.tfvars -out=tfplan
terraform apply tfplan
```

After apply:
1. Put the outputs into GitHub variables (see `../README.md`): `tfstate_storage_account`, `acr_name`, `github_identity_client_ids`.
2. Move the bootstrap's own state into the storage account just created (optional): add a `backend "azurerm" {}` block, then `terraform init -migrate-state`.
3. Configure the GitHub Environments per the runbook `docs/04-devops/github-setup.md` (application repo): `infra-uat`, `infra-uat-destroy`, `infra-prod`, `infra-prod-destroy`.

Note: the identities that provision environments have `Contributor` + `Role Based Access Control Administrator` at subscription scope (needed to create resources and assign roles).
When prod moves to its own subscription (NFR-D4), narrow this scope.

## Environments that block `Microsoft.Authorization/*/Write` (sandbox)

Some subscriptions (for example the `FSO-SandboxOps` sandbox) allow creating resources but **forbid every role-assignment write**
and **grant no `dataActions`**. Check with:

```bash
az role definition list --name <role> -o json                     # look at notActions / dataActions
az rest --url "https://management.azure.com/subscriptions/<sub>/providers/Microsoft.Authorization/permissions?api-version=2022-04-01"
```

In such an environment, set in `bootstrap.tfvars`:

```hcl
create_role_assignments = false   # do not create role assignments
manage_state_container  = false   # do not create the container through Entra (no dataActions)
acr_sku                 = "Basic" # depending on the budget
```

`terraform apply` then creates 19 resources: the resource group, the storage account (versioning, 30-day soft delete, shared
keys off), ACR (admin off), 6 managed identities + federated credentials for GitHub OIDC, and the monthly budget.

Two things remain that need an **Owner** account on the subscription (once):

```bash
# 1) Role assignments: take the exact commands from the output
terraform output -json required_role_assignments

# 2) State container: use an account with "Storage Blob Data Contributor" on the storage account
az storage container create --account-name <tfstate_storage_account> --name tfstate --auth-mode login
```

Then set the GitHub variables per `../README.md`; the GitHub identities only work after step 1.
