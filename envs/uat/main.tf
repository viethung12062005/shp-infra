data "azurerm_client_config" "current" {}

data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group
}

module "environment" {
  source = "../../modules/environment"

  environment          = "uat"
  location             = var.location
  tenant_id            = data.azurerm_client_config.current.tenant_id
  acr_id               = data.azurerm_container_registry.acr.id
  sizing               = var.sizing
  address_space        = "10.60.0.0/16"
  created_at           = var.created_at
  ttl_hours            = var.ttl_hours
  enable_ai_pool       = var.enable_ai_pool
  authorized_ip_ranges = var.authorized_ip_ranges
}
