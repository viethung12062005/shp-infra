output "postgres_fqdn" {
  description = "Host of the IAM PostgreSQL server (KC_DB_URL_HOST). Resolves only inside the VNet."
  value       = module.postgres.fqdn
}

output "postgres_name" {
  description = "Name of the IAM PostgreSQL server."
  value       = module.postgres.name
}

output "database_name" {
  description = "Database Keycloak uses (KC_DB_URL_DATABASE)."
  value       = var.database_name
}

output "db_username" {
  description = "KC_DB_USERNAME: the password login in password mode, the managed identity name in entra mode."
  value       = local.password_mode ? var.db_login : module.identity.names[var.service_account_name]
}

output "identity_client_id" {
  description = "Client id of the Keycloak workload identity (azure.workload.identity/client-id on the ServiceAccount)."
  value       = module.identity.client_ids[var.service_account_name]
}

output "identity_principal_id" {
  description = "Principal (object) id of the Keycloak workload identity."
  value       = module.identity.principal_ids[var.service_account_name]
}

output "identity_name" {
  description = "Managed identity name; the PostgreSQL (Entra) login of Keycloak in entra mode."
  value       = module.identity.names[var.service_account_name]
}

output "key_vault_secret_names" {
  description = "Names (never values) of the Keycloak secrets in Key Vault, mounted through the Secrets Store CSI driver."
  value       = local.secret_names
}

output "namespace" {
  description = "Namespace the federated credential trusts."
  value       = var.namespace
}

output "service_account_name" {
  description = "ServiceAccount the federated credential trusts."
  value       = var.service_account_name
}
