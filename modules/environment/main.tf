locals {
  name_prefix = "shp-${var.environment}"
  is_prod     = var.environment == "prod"

  tags = merge(var.extra_tags, {
    "shp-env"    = var.environment
    "created-at" = var.created_at
    "ttl-hours"  = tostring(var.ttl_hours)
    "managed-by" = "terraform"
  })

  sizing = {
    small = {
      system = { vm_size = "Standard_D2s_v5", min_count = 1, max_count = 2 }
      apps   = { vm_size = "Standard_D4s_v5", min_count = 2, max_count = 4, spot = !local.is_prod }
      # Ollama: bge-m3 + qwen2.5-7b need about 8-10 GB RAM, so the pool scales to zero when idle. For a GPU SKU
      # (for example Standard_NC4as_T4_v3) add gpu_driver = "Install" to this object.
      ai = { vm_size = "Standard_D4s_v5", min_count = 0, max_count = 1, os_disk_size_gb = 128 }
      data = {
        pg_sku           = "B_Standard_B1ms"
        pg_storage_mb    = 32768
        pg_ha            = null
        pg_backup_days   = 7
        pg_geo_backup    = false
        mongo_tier       = "M10"
        mongo_storage_gb = 32
        mongo_ha         = "Disabled"
        redis_sku        = "Balanced_B0"
        redis_ha         = false
        replication      = "LRS"
        search_sku       = "basic"
        search_replicas  = 1
      }
    }
    prod = {
      system = { vm_size = "Standard_D2s_v5", min_count = 3, max_count = 3 }
      apps   = { vm_size = "Standard_D4s_v5", min_count = 3, max_count = 10, spot = false }
      # 32 GB RAM and a 256 GB OS disk keep the model cache and images local; the pool still scales to zero.
      ai = { vm_size = "Standard_D8s_v5", min_count = 0, max_count = 2, os_disk_size_gb = 256 }
      data = {
        pg_sku           = "GP_Standard_D2ds_v5"
        pg_storage_mb    = 131072
        pg_ha            = "ZoneRedundant"
        pg_backup_days   = 35
        pg_geo_backup    = true
        mongo_tier       = "M30"
        mongo_storage_gb = 128
        mongo_ha         = "ZoneRedundantPreferred"
        redis_sku        = "Balanced_B5"
        redis_ha         = true
        replication      = "ZRS"
        search_sku       = "standard"
        search_replicas  = 2
      }
    }
  }

  data = local.sizing[var.sizing].data

  # One identity per service; the name is also the ServiceAccount name (chart values set serviceAccount.name = service name).
  services = ["scheduling", "notification", "clinical", "document", "ai", "ml", "audit", "gateway"]

  # Mongo database of each service (ADR-0014). scheduling uses PostgreSQL, audit uses Blob, gateway uses Redis.
  mongo_databases = {
    clinical     = ["clinical"]
    document     = ["document"]
    ai           = ["ai"]
    notification = ["notification"]
    ml           = ["ml"]
  }

  # Services that have a Service Bus subscription (matches the default keys of the servicebus module)
  event_consumers = ["notification", "ml", "clinical", "scheduling", "document", "ai", "audit"]
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

# Required tags are enforced with Azure Policy (deny) instead of being set "by convention only" (IAC-04).
module "tag_policy" {
  count  = var.create_tag_policy ? 1 : 0
  source = "../tag-policy"

  resource_group_id = azurerm_resource_group.this.id
}

module "network" {
  source              = "../network"
  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  tags                = local.tags
  address_space       = var.address_space

  # Private DNS zones accept at most 15 tags. A tag policy can also add about ten inherited tags, so keep every
  # extra tag (they include the inherited ones, which avoids drift) but only shp-env of the shp-* tags (15 in all).
  private_dns_zone_tags = { for k, v in local.tags : k => v if !contains(["created-at", "ttl-hours", "managed-by"], k) }
}

module "monitoring" {
  source              = "../monitoring"
  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  tags                = local.tags
}

module "keyvault" {
  source                      = "../keyvault"
  name_prefix                 = local.name_prefix
  resource_group_name         = azurerm_resource_group.this.name
  location                    = var.location
  tags                        = local.tags
  tenant_id                   = var.tenant_id
  purge_protection_enabled    = local.is_prod
  soft_delete_retention_days  = local.is_prod ? 30 : 7
  private_endpoints_subnet_id = module.network.private_endpoints_subnet_id
  private_dns_zone_id         = module.network.private_dns_zone_ids["privatelink.vaultcore.azure.net"]

  # The ai pod reads the DeepSeek/Gemini keys through the Secrets Store CSI driver with its workload identity.
  secret_reader_principal_ids = { ai = module.identities.principal_ids["ai"] }
  create_role_assignments     = var.create_role_assignments
}

module "aks" {
  source                     = "../aks"
  name_prefix                = local.name_prefix
  resource_group_name        = azurerm_resource_group.this.name
  location                   = var.location
  tags                       = local.tags
  tenant_id                  = var.tenant_id
  kubernetes_version         = var.kubernetes_version
  sku_tier                   = local.is_prod ? "Standard" : "Free"
  subnet_id                  = module.network.aks_subnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  authorized_ip_ranges       = var.authorized_ip_ranges
  private_cluster_enabled    = var.aks_private_cluster
  local_accounts_enabled     = var.aks_local_accounts_enabled
  entra_rbac_enabled         = var.aks_entra_rbac_enabled
  system_pool                = local.sizing[var.sizing].system
  apps_pool                  = local.sizing[var.sizing].apps
  ai_pool                    = local.sizing[var.sizing].ai
  enable_ai_pool             = var.enable_ai_pool
  acr_id                     = var.acr_id
  create_role_assignments    = var.create_role_assignments
}

module "observability" {
  source                       = "../observability"
  name_prefix                  = local.name_prefix
  resource_group_name          = azurerm_resource_group.this.name
  resource_group_id            = azurerm_resource_group.this.id
  location                     = var.location
  tags                         = local.tags
  aks_id                       = module.aks.id
  aks_name                     = module.aks.name
  monitor_workspace_id         = module.monitoring.monitor_workspace_id
  log_analytics_workspace_id   = module.monitoring.log_analytics_workspace_id
  grafana_admin_principal_ids  = var.grafana_admin_principal_ids
  grafana_viewer_principal_ids = var.grafana_viewer_principal_ids
  create_role_assignments      = var.create_role_assignments
}

module "identities" {
  source              = "../workload-identity"
  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  tags                = local.tags
  oidc_issuer_url     = module.aks.oidc_issuer_url
  services            = local.services
}

# One-time cluster objects for the ai workload (Ollama model cache + Key Vault CSI reference). Opt-in: the
# Kubernetes provider needs a kubeconfig, which does not exist during the first apply that creates the cluster.
module "ai_workload" {
  source = "../ai-workload"

  enabled                = var.enable_ai_workload && var.enable_ai_pool
  kubeconfig_path        = var.kubeconfig_path
  key_vault_name         = module.keyvault.name
  tenant_id              = var.tenant_id
  ai_client_id           = module.identities.client_ids["ai"]
  model_cache_size       = var.ai_model_cache_size
  key_vault_secret_names = var.ai_key_vault_secret_names
}

module "postgres" {
  source                     = "../postgres"
  name_prefix                = local.name_prefix
  resource_group_name        = azurerm_resource_group.this.name
  location                   = var.location
  tags                       = local.tags
  tenant_id                  = var.tenant_id
  delegated_subnet_id        = module.network.postgres_subnet_id
  private_dns_zone_id        = module.network.private_dns_zone_ids["privatelink.postgres.database.azure.com"]
  entra_admin                = var.entra_admin
  sku_name                   = local.data.pg_sku
  storage_mb                 = local.data.pg_storage_mb
  high_availability          = local.data.pg_ha
  backup_retention_days      = local.data.pg_backup_days
  geo_redundant_backup       = local.data.pg_geo_backup
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  create_entra_admin         = var.create_entra_admin
}

module "mongodb" {
  source                      = "../mongodb"
  name_prefix                 = local.name_prefix
  resource_group_name         = azurerm_resource_group.this.name
  location                    = var.location
  tags                        = local.tags
  private_endpoints_subnet_id = module.network.private_endpoints_subnet_id
  private_dns_zone_id         = module.network.private_dns_zone_ids["privatelink.mongocluster.cosmos.azure.com"]
  compute_tier                = local.data.mongo_tier
  storage_size_in_gb          = local.data.mongo_storage_gb
  high_availability_mode      = local.data.mongo_ha

  service_users = {
    for svc, dbs in local.mongo_databases : svc => {
      object_id = module.identities.principal_ids[svc]
      databases = dbs
    }
  }
}

module "redis" {
  source                      = "../redis"
  name_prefix                 = local.name_prefix
  resource_group_name         = azurerm_resource_group.this.name
  location                    = var.location
  tags                        = local.tags
  private_endpoints_subnet_id = module.network.private_endpoints_subnet_id
  private_dns_zone_id         = module.network.private_dns_zone_ids["privatelink.redis.azure.net"]
  sku_name                    = local.data.redis_sku
  high_availability_enabled   = local.data.redis_ha

  client_principal_ids = {
    gateway    = module.identities.principal_ids["gateway"]
    scheduling = module.identities.principal_ids["scheduling"]
  }
}

module "servicebus" {
  source                      = "../servicebus"
  name_prefix                 = local.name_prefix
  resource_group_name         = azurerm_resource_group.this.name
  location                    = var.location
  tags                        = local.tags
  private_endpoints_subnet_id = module.network.private_endpoints_subnet_id
  private_dns_zone_id         = module.network.private_dns_zone_ids["privatelink.servicebus.windows.net"]
  sku                         = var.messaging_sku
  log_analytics_workspace_id  = module.monitoring.log_analytics_workspace_id

  # Every service emits audit (E11), so all of them may send; only consumers with a subscription may receive
  create_role_assignments = var.create_role_assignments
  sender_principal_ids    = module.identities.principal_ids
  receiver_principal_ids  = { for svc in local.event_consumers : svc => module.identities.principal_ids[svc] }

  # Defender for Storage writes malware scan results here; the document service is the only consumer.
  queues = {
    malware-scan-results = {
      max_delivery_count  = 10
      default_message_ttl = "P1D"
    }
  }
  queue_receiver_principal_ids = {
    malware-scan-results = module.identities.principal_ids["document"]
  }
}

module "storage" {
  source                      = "../storage"
  name_prefix                 = local.name_prefix
  resource_group_name         = azurerm_resource_group.this.name
  location                    = var.location
  tags                        = local.tags
  private_endpoints_subnet_id = module.network.private_endpoints_subnet_id
  private_dns_zone_id         = module.network.private_dns_zone_ids["privatelink.blob.core.windows.net"]
  log_analytics_workspace_id  = module.monitoring.log_analytics_workspace_id
  replication_type            = local.data.replication
  audit_retention_days        = local.is_prod ? 3650 : 1
  audit_retention_locked      = local.is_prod

  document_writer_principal_ids = { document = module.identities.principal_ids["document"] }
  kb_reader_principal_ids       = { ai = module.identities.principal_ids["ai"] }
  ml_principal_ids              = { ml = module.identities.principal_ids["ml"] }
  audit_writer_principal_ids    = { audit = module.identities.principal_ids["audit"] }
  create_role_assignments       = var.create_role_assignments
  create_containers             = var.create_containers
}

module "defender_storage" {
  source = "../defender-storage"

  name_prefix                = local.name_prefix
  resource_group_name        = azurerm_resource_group.this.name
  location                   = var.location
  tags                       = local.tags
  storage_account_id         = module.storage.docs_account_id
  servicebus_queue_id        = module.servicebus.queue_ids["malware-scan-results"]
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  enabled                    = var.enable_malware_scan
  create_role_assignments    = var.create_role_assignments
}

module "search" {
  source                      = "../search"
  name_prefix                 = local.name_prefix
  resource_group_name         = azurerm_resource_group.this.name
  location                    = var.location
  tags                        = local.tags
  private_endpoints_subnet_id = module.network.private_endpoints_subnet_id
  private_dns_zone_id         = module.network.private_dns_zone_ids["privatelink.search.windows.net"]
  sku                         = local.data.search_sku
  replica_count               = local.data.search_replicas

  index_contributor_principal_ids = { ai = module.identities.principal_ids["ai"] }
  create_role_assignments         = var.create_role_assignments
}
