# Azure side of Keycloak (ADR-0017, IAC-16): a dedicated PostgreSQL server, the workload identity of the Keycloak
# pods and the secrets Keycloak needs, kept only in Key Vault. The Kubernetes objects (chart, /idp route through
# the Gateway, NetworkPolicy) belong to shp-gitops (IAM-01) and consume the outputs of this module.
locals {
  password_mode = var.db_auth == "password"

  # Secret name -> value. The database password exists only in password mode. The bootstrap admin password is
  # what Keycloak reads once to create its first administrator (KC_BOOTSTRAP_ADMIN_PASSWORD).
  secret_names = concat(
    local.password_mode ? ["keycloak-db-password"] : [],
    ["keycloak-admin-password"],
  )
  secret_values = {
    keycloak-db-password    = random_password.db.result
    keycloak-admin-password = random_password.admin.result
  }
}

# A second Flexible Server, not a second database on the scheduling server: ADR-0017 asks for isolation and
# independent recovery, and point-in-time restore, HA failover, maintenance and the password switch below are all
# per server. Restoring IAM must never roll scheduling back, and the reverse.
module "postgres" {
  source                     = "../postgres"
  name_prefix                = "${var.name_prefix}-iam"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tags                       = var.tags
  tenant_id                  = var.tenant_id
  delegated_subnet_id        = var.delegated_subnet_id
  private_dns_zone_id        = var.private_dns_zone_id
  entra_admin                = var.entra_admin
  create_entra_admin         = var.create_entra_admin
  sku_name                   = var.sku_name
  storage_mb                 = var.storage_mb
  high_availability          = var.high_availability
  backup_retention_days      = var.backup_retention_days
  geo_redundant_backup       = var.geo_redundant_backup
  log_analytics_workspace_id = var.log_analytics_workspace_id
  databases                  = [var.database_name]
  extensions                 = []

  # Entra sign-in stays on in both modes. In password mode the only password login is Keycloak's.
  password_admin_login    = local.password_mode ? var.db_login : null
  password_admin_password = local.password_mode ? random_password.db.result : null
}

# Generated here, stored in the encrypted state and in Key Vault, never an output. The special characters are safe
# in a JDBC URL and in an environment variable.
resource "random_password" "db" {
  length           = 40
  special          = true
  override_special = "-_.~"
  min_upper        = 4
  min_lower        = 4
  min_numeric      = 4
  min_special      = 2
}

resource "random_password" "admin" {
  length           = 40
  special          = true
  override_special = "-_.~"
  min_upper        = 4
  min_lower        = 4
  min_numeric      = 4
  min_special      = 2
}

# The vault has no public access, so a runner outside the VNet cannot call its data plane
# (azurerm_key_vault_secret would time out). Secrets are also an ARM resource type, and Azure Resource Manager is a
# trusted path into the vault: the deployment needs Microsoft.KeyVault/vaults/secrets/write (part of Contributor)
# and no network path. The value is a securestring parameter, which ARM does not keep in the deployment history.
resource "azurerm_resource_group_template_deployment" "secret" {
  for_each = var.create_key_vault_secrets ? toset(local.secret_names) : toset([])

  name                = "kv-secret-${each.value}"
  resource_group_name = var.resource_group_name
  deployment_mode     = "Incremental"
  tags                = var.tags

  template_content = jsonencode({
    "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    parameters = {
      vaultName   = { type = "string" }
      secretName  = { type = "string" }
      secretValue = { type = "securestring" }
    }
    resources = [{
      type       = "Microsoft.KeyVault/vaults/secrets"
      apiVersion = "2023-07-01"
      name       = "[concat(parameters('vaultName'), '/', parameters('secretName'))]"
      properties = {
        value       = "[parameters('secretValue')]"
        contentType = "text/plain"
      }
    }]
  })

  parameters_content = jsonencode({
    vaultName   = { value = var.key_vault_name }
    secretName  = { value = each.value }
    secretValue = { value = local.secret_values[each.value] }
  })
}

# Identity of the Keycloak pods, bound to one ServiceAccount in the IAM namespace.
module "identity" {
  source              = "../workload-identity"
  name_prefix         = var.name_prefix
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  oidc_issuer_url     = var.oidc_issuer_url
  namespace           = var.namespace
  services            = [var.service_account_name]
}

# Read access to its own secrets only: the scope is each secret, not the vault, so Keycloak cannot read the keys
# of another service and no other identity is granted these.
resource "azurerm_role_assignment" "secret_reader" {
  for_each = var.create_role_assignments ? toset(local.secret_names) : toset([])

  scope                = "${var.key_vault_id}/secrets/${each.value}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.identity.principal_ids[var.service_account_name]

  # The scope must exist before a role can be assigned on it.
  depends_on = [azurerm_resource_group_template_deployment.secret]
}
