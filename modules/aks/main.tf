resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.name_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  tags                = var.tags

  # Danh tính và bảo mật
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  local_account_disabled            = true
  role_based_access_control_enabled = true
  image_cleaner_enabled             = true
  automatic_upgrade_channel         = "patch"
  node_os_upgrade_channel           = "NodeImage"

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = var.tenant_id
  }

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_pool.vm_size
    vnet_subnet_id               = var.subnet_id
    zones                        = var.zones
    auto_scaling_enabled         = true
    min_count                    = var.system_pool.min_count
    max_count                    = var.system_pool.max_count
    only_critical_addons_enabled = true
    os_disk_size_gb              = 64
    upgrade_settings {
      max_surge = "33%"
    }
  }

  # Azure CNI Overlay + Cilium (NetworkPolicy mặc định chặn, xem GOP-08)
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.245.0.0/16"
    dns_service_ip      = "10.245.0.10"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  # Managed Prometheus: bật agent thu metric; quy tắc thu và đích nằm ở module observability
  monitor_metrics {}

  api_server_access_profile {
    authorized_ip_ranges = var.authorized_ip_ranges
  }

  lifecycle {
    ignore_changes = [default_node_pool[0].node_count]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.apps_pool.vm_size
  vnet_subnet_id        = var.subnet_id
  zones                 = var.zones
  auto_scaling_enabled  = true
  min_count             = var.apps_pool.min_count
  max_count             = var.apps_pool.max_count
  os_disk_size_gb       = 64
  priority              = var.apps_pool.spot ? "Spot" : "Regular"
  eviction_policy       = var.apps_pool.spot ? "Delete" : null
  spot_max_price        = var.apps_pool.spot ? -1 : null
  node_labels           = { "shp/pool" = "apps" }
  tags                  = var.tags

  upgrade_settings {
    max_surge = "33%"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "ai" {
  count                 = var.enable_ai_pool ? 1 : 0
  name                  = "ai"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.ai_pool.vm_size
  vnet_subnet_id        = var.subnet_id
  zones                 = var.zones
  auto_scaling_enabled  = true
  min_count             = var.ai_pool.min_count
  max_count             = var.ai_pool.max_count
  os_disk_size_gb       = 128
  node_labels           = { "shp/pool" = "ai" }
  node_taints           = ["workload=ai:NoSchedule"]
  tags                  = var.tags

  upgrade_settings {
    max_surge = "33%"
  }
}

# Kéo image từ ACR bằng danh tính của kubelet (không dùng admin/user-pass)
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}
