output "resource_group_name" { value = azurerm_resource_group.this.name }
output "aks_name" { value = module.aks.name }
output "aks_oidc_issuer_url" { value = module.aks.oidc_issuer_url }
output "key_vault_name" { value = module.keyvault.name }
output "log_analytics_workspace_id" { value = module.monitoring.log_analytics_workspace_id }
output "aks_id" { value = module.aks.id }
output "postgres_fqdn" { value = module.postgres.fqdn }
output "postgres_name" { value = module.postgres.name }
output "mongo_cluster_name" { value = module.mongodb.name }
output "redis_name" { value = module.redis.name }
output "servicebus_endpoint" { value = module.servicebus.endpoint }
output "docs_storage_account" { value = module.storage.docs_account_name }
output "audit_storage_account" { value = module.storage.audit_account_name }
output "search_name" { value = module.search.name }
output "grafana_endpoint" { value = module.observability.grafana_endpoint }

output "workload_identity_client_ids" {
  description = "service -> clientId, điền vào workloadIdentity.clientId trong shp-gitops."
  value       = module.identities.client_ids
}
