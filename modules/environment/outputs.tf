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
output "malware_scan_results_queue" { value = module.servicebus.queue_names["malware-scan-results"] }
output "malware_scan_event_subscription_id" { value = module.defender_storage.event_subscription_id }
output "kb_container_name" { value = module.storage.kb_container_name }
output "audit_storage_account" { value = module.storage.audit_account_name }
output "search_name" { value = module.search.name }
output "grafana_endpoint" { value = module.observability.grafana_endpoint }

output "workload_identity_client_ids" {
  description = "service -> clientId; goes into workloadIdentity.clientId in shp-gitops."
  value       = module.identities.client_ids
}

output "workload_identity_names" {
  description = "service -> managed identity name; scheduling uses it as SPRING_DATASOURCE_USERNAME in shp-gitops."
  value       = module.identities.names
}

output "ai_pool_name" {
  value = module.aks.ai_pool_name
}

output "ai_pool_node_labels" {
  description = "nodeSelector for the ai-service and Ollama pods."
  value       = module.aks.ai_pool_node_labels
}

output "ai_pool_node_taints" {
  description = "Taints the ai-service and Ollama pods must tolerate."
  value       = module.aks.ai_pool_node_taints
}

output "ai_model_cache_pvc" {
  value = module.ai_workload.model_cache_pvc_name
}

output "ai_key_vault_secret_provider_class" {
  value = module.ai_workload.secret_provider_class_name
}

output "ai_service_values" {
  description = "Copy into shp-gitops envs/<env>/ai/values.yaml (SCF-06): pin the pod to the ai pool and load the API keys through the CSI driver."
  value = {
    nodeSelector = module.aks.ai_pool_node_labels
    tolerations = var.enable_ai_pool ? [{
      key      = "workload"
      operator = "Equal"
      value    = "ai"
      effect   = "NoSchedule"
    }] : []
    resources = {
      requests = { memory = "8Gi" }
      limits   = { memory = "10Gi" }
    }
    keyVault = {
      enabled  = true
      name     = module.keyvault.name
      tenantId = var.tenant_id
      objects  = [for name in var.ai_key_vault_secret_names : { name = name, type = "secret" }]
    }
    workloadIdentity = { clientId = module.identities.client_ids["ai"] }
  }
}

output "keycloak_values" {
  description = "Non-secret values for shp-gitops (IAM-01): database, workload identity and Key Vault secret names for Keycloak. Secret values are never output."
  value = {
    namespace      = module.keycloak_infra.namespace
    serviceAccount = module.keycloak_infra.service_account_name
    database = {
      host     = module.keycloak_infra.postgres_fqdn
      name     = module.keycloak_infra.database_name
      username = module.keycloak_infra.db_username
      auth     = var.keycloak_db_auth
    }
    workloadIdentity = { clientId = module.keycloak_infra.identity_client_id }
    keyVault = {
      name       = module.keyvault.name
      tenantId   = var.tenant_id
      secretKeys = module.keycloak_infra.key_vault_secret_names
    }
  }
}

output "data_access" {
  description = <<-EOT
    service -> what that service may use, derived from the same locals that feed the role assignments and database
    users (IAC-20). PostgreSQL is listed for scheduling only: the database role itself is created after apply
    (modules/postgres/README.md). Used by tests/data-access.tftest.hcl; contains no secrets.
  EOT
  value = {
    for svc in local.services : svc => {
      postgres_databases = svc == "scheduling" ? ["scheduling"] : []
      mongo_databases    = lookup(local.mongo_databases, svc, [])
      redis              = contains(local.redis_clients, svc)
      blob_documents     = contains(local.document_writers, svc)
      blob_kb            = contains(local.kb_readers, svc)
      blob_mlops         = contains(local.ml_users, svc)
      blob_audit         = contains(local.audit_writers, svc)
      search             = contains(local.search_contributors, svc)
      key_vault_secrets  = contains(local.key_vault_readers, svc)
      servicebus_send    = true
      servicebus_receive = contains(local.event_consumers, svc)
    }
  }
}
