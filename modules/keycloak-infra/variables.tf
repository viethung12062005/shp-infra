variable "name_prefix" {
  description = "Environment prefix, for example shp-uat."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group of the environment."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "tags" {
  description = "Required environment tags."
  type        = map(string)
}

variable "tenant_id" {
  description = "Entra tenant of the PostgreSQL server and the Key Vault."
  type        = string
}

variable "delegated_subnet_id" {
  description = "Subnet delegated to PostgreSQL Flexible Server. Shared with the scheduling server; each server still has its own address, storage and backups."
  type        = string
}

variable "private_dns_zone_id" {
  description = "privatelink.postgres.database.azure.com zone linked to the VNet."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Workspace that receives the PostgreSQL logs and metrics."
  type        = string
}

variable "entra_admin" {
  description = "Entra ID administrator of the IAM server (the identity that runs Terraform). Used for break-glass and for creating the Entra role in entra mode."
  type = object({
    object_id = string
    name      = string
    type      = string
  })
}

variable "create_entra_admin" {
  description = "Assign the Entra administrator. Set false where microsoft.aadiam/*/write is blocked (sandbox)."
  type        = bool
  default     = true
}

variable "sku_name" {
  description = "B_Standard_B1ms for test environments; a General Purpose SKU in prod (zone-redundant HA is not offered on Burstable)."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage of the IAM server. Keycloak data is small; auto-grow is on."
  type        = number
  default     = 32768
}

variable "high_availability" {
  description = "ZoneRedundant in prod (one Keycloak outage stops every sign-in, ADR-0017); null = off."
  type        = string
  default     = null
}

variable "backup_retention_days" {
  description = "Point-in-time restore window of the IAM server, independent of the scheduling server."
  type        = number
  default     = 7
}

variable "geo_redundant_backup" {
  description = "Geo-redundant backups (prod)."
  type        = bool
  default     = false
}

variable "database_name" {
  description = "Database Keycloak uses (KC_DB_URL_DATABASE)."
  type        = string
  default     = "keycloak"
}

variable "db_auth" {
  description = <<-EOT
    How Keycloak signs in to its database (ADR-0017 leaves the final choice to IAM-01).
    password: stock Keycloak image; a generated password is kept only in Key Vault and the server allows password
    sign-in for that single login. entra: password sign-in off like the scheduling server; the pod signs in with its
    workload identity (needs the Azure JDBC authentication plugin in the Keycloak image).
  EOT
  type        = string
  default     = "password"
  validation {
    condition     = contains(["password", "entra"], var.db_auth)
    error_message = "db_auth must be password or entra."
  }
}

variable "db_login" {
  description = "PostgreSQL login of Keycloak in password mode."
  type        = string
  default     = "keycloak"
}

variable "oidc_issuer_url" {
  description = "OIDC issuer of the AKS cluster, for the federated credential."
  type        = string
}

variable "namespace" {
  description = "Namespace Keycloak runs in (ADR-0017). Must match the namespace in shp-gitops."
  type        = string
  default     = "shp-iam"
}

variable "service_account_name" {
  description = "ServiceAccount of the Keycloak pods. Must match the ServiceAccount in shp-gitops."
  type        = string
  default     = "keycloak"
}

variable "key_vault_id" {
  description = "Key Vault of the environment; the Keycloak secrets are written into it."
  type        = string
}

variable "key_vault_name" {
  description = "Name of the same Key Vault."
  type        = string
}

variable "create_key_vault_secrets" {
  description = "Write the generated secrets into Key Vault. Set false where the deploying identity lacks Microsoft.KeyVault/vaults/secrets/write."
  type        = bool
  default     = true
}

variable "create_role_assignments" {
  description = <<-EOT
    Create the role assignments of the module (Keycloak identity reads its own secrets). Set false where
    Microsoft.Authorization/*/Write is blocked (sandbox); the Owner runs `az role assignment create` afterwards.
  EOT
  type        = bool
  default     = true
}
