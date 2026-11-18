data "azurerm_client_config" "current" {}

data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group
}

module "environment" {
  source = "../../modules/environment"

  environment                          = "prod"
  location                             = var.location
  tenant_id                            = data.azurerm_client_config.current.tenant_id
  acr_id                               = data.azurerm_container_registry.acr.id
  sizing                               = var.sizing
  address_space                        = "10.70.0.0/16"
  created_at                           = var.created_at
  ttl_hours                            = var.ttl_hours
  enable_ai_pool                       = var.enable_ai_pool
  extra_tags                           = var.extra_tags
  aks_zones                            = var.aks_zones
  aks_system_pool_critical_addons_only = var.aks_system_pool_critical_addons_only
  storage_shared_key_enabled           = var.storage_shared_key_enabled
  redis_access_keys_enabled            = var.redis_access_keys_enabled
  aks_private_cluster                  = var.aks_private_cluster
  aks_local_accounts_enabled           = var.aks_local_accounts_enabled
  aks_entra_rbac_enabled               = var.aks_entra_rbac_enabled
  enable_malware_scan                  = var.enable_malware_scan
  enable_ai_workload                   = var.enable_ai_workload
  kubeconfig_path                      = var.kubeconfig_path
  authorized_ip_ranges                 = var.authorized_ip_ranges

  # The identity that runs Terraform is the Entra administrator of PostgreSQL (the server has no password)
  entra_admin = {
    object_id = data.azurerm_client_config.current.object_id
    name      = var.entra_admin_name
    type      = var.entra_admin_type
  }

  messaging_sku = var.messaging_sku

  # The Sandbox blocks Microsoft.Authorization/*/Write and has no dataActions: set false in *.tfvars
  create_role_assignments      = var.create_role_assignments
  create_containers            = var.create_containers
  create_entra_admin           = var.create_entra_admin
  create_tag_policy            = var.create_tag_policy
  grafana_admin_principal_ids  = var.grafana_admin_principal_ids
  grafana_viewer_principal_ids = var.grafana_viewer_principal_ids
}
