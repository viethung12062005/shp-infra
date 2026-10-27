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
    }
    prod = {
      system = { vm_size = "Standard_D2s_v5", min_count = 3, max_count = 3 }
      apps   = { vm_size = "Standard_D4s_v5", min_count = 3, max_count = 10, spot = false }
    }
  }
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
