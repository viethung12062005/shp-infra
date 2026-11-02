output "resource_group_name" {
  value = module.environment.resource_group_name
}

output "aks_name" {
  value = module.environment.aks_name
}

output "aks_oidc_issuer_url" {
  value = module.environment.aks_oidc_issuer_url
}

output "key_vault_name" {
  value = module.environment.key_vault_name
}

output "workload_identity_client_ids" {
  description = "service -> clientId, điền vào workloadIdentity.clientId trong shp-gitops."
  value       = module.environment.workload_identity_client_ids
}

output "workload_identity_names" {
  description = "service -> tên managed identity; scheduling dùng làm SPRING_DATASOURCE_USERNAME trong shp-gitops."
  value       = module.environment.workload_identity_names
}

output "postgres_fqdn" {
  description = "Host PostgreSQL, dùng trong SPRING_DATASOURCE_URL của scheduling (shp-gitops)."
  value       = module.environment.postgres_fqdn
}

output "grafana_endpoint" {
  value = module.environment.grafana_endpoint
}
