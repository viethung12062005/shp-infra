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

output "malware_scan_results_queue" {
  description = "Queue the document service consumes for Defender malware scan results."
  value       = module.environment.malware_scan_results_queue
}

output "ai_pool_name" {
  value = module.environment.ai_pool_name
}

output "ai_model_cache_pvc" {
  description = "Ollama model cache PVC once enable_ai_workload is applied; null on the first apply."
  value       = module.environment.ai_model_cache_pvc
}

output "ai_service_values" {
  description = "Values to copy into shp-gitops envs/uat/ai/values.yaml (SCF-06)."
  value       = module.environment.ai_service_values
}

output "workload_identity_client_ids" {
  description = "service -> clientId; goes into workloadIdentity.clientId in shp-gitops."
  value       = module.environment.workload_identity_client_ids
}

output "workload_identity_names" {
  description = "service -> managed identity name; scheduling uses it as SPRING_DATASOURCE_USERNAME in shp-gitops."
  value       = module.environment.workload_identity_names
}

output "postgres_fqdn" {
  description = "PostgreSQL host, used in SPRING_DATASOURCE_URL of scheduling (shp-gitops)."
  value       = module.environment.postgres_fqdn
}

output "keycloak_values" {
  description = "Non-secret Keycloak values for shp-gitops envs/uat (IAM-01): IAM database host, workload identity client id, Key Vault secret names."
  value       = module.environment.keycloak_values
}

output "grafana_endpoint" {
  value = module.environment.grafana_endpoint
}
