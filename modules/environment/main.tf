locals {
  name_prefix = "shp-${var.environment}"
  is_prod     = var.environment == "prod"

  tags = {
    "shp-env"    = var.environment
    "created-at" = var.created_at
    "ttl-hours"  = tostring(var.ttl_hours)
    "managed-by" = "terraform"
  }

  sizing = {
    small = {
      system = { vm_size = "Standard_D2s_v5", min_count = 1, max_count = 2 }
      apps   = { vm_size = "Standard_D4s_v5", min_count = 2, max_count = 4, spot = !local.is_prod }
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

  # Mỗi service một danh tính; tên cũng là tên ServiceAccount (values của chart đặt serviceAccount.name = tên service).
  services = ["scheduling", "notification", "clinical", "document", "ai", "ml", "audit", "gateway"]

  # Database Mongo của từng service (ADR-0014). scheduling dùng PostgreSQL, audit dùng Blob, gateway dùng Redis.
  mongo_databases = {
    clinical     = ["clinical"]
    document     = ["document"]
    ai           = ["ai"]
    notification = ["notification"]
    ml           = ["ml"]
  }

  # Service có subscription trên Service Bus (khớp khóa mặc định của module servicebus)
  event_consumers = ["notification", "ml", "clinical", "scheduling", "document", "ai", "audit"]
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

module "network" {
  source              = "../network"
  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  tags                = local.tags
  address_space       = var.address_space
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
  system_pool                = local.sizing[var.sizing].system
  apps_pool                  = local.sizing[var.sizing].apps
  enable_ai_pool             = var.enable_ai_pool
  acr_id                     = var.acr_id
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

  # Mọi service phát audit (E11) nên đều được gửi; chỉ consumer có subscription mới được nhận
  sender_principal_ids   = module.identities.principal_ids
  receiver_principal_ids = { for svc in local.event_consumers : svc => module.identities.principal_ids[svc] }
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
  defender_malware_scan       = local.is_prod

  document_writer_principal_ids = { document = module.identities.principal_ids["document"] }
  kb_reader_principal_ids       = { ai = module.identities.principal_ids["ai"] }
  ml_principal_ids              = { ml = module.identities.principal_ids["ml"] }
  audit_writer_principal_ids    = { audit = module.identities.principal_ids["audit"] }
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
}
