locals {
  # A subscription may have no availability zones for the chosen VM size and region; an empty list means no zones.
  zones = length(var.zones) == 0 ? null : var.zones
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.name_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  tags                = var.tags

  # Identity and security
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  local_account_disabled            = !var.local_accounts_enabled
  private_cluster_enabled           = var.private_cluster_enabled
  role_based_access_control_enabled = true
  image_cleaner_enabled             = true
  image_cleaner_interval_hours      = 48 # AKS rejects 0; the allowed range is 24 to 2160
  automatic_upgrade_channel         = "patch"
  node_os_upgrade_channel           = "NodeImage"

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.entra_rbac_enabled ? [1] : []
    content {
      azure_rbac_enabled = true
      tenant_id          = var.tenant_id
    }
  }

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_pool.vm_size
    vnet_subnet_id               = var.subnet_id
    zones                        = local.zones
    auto_scaling_enabled         = true
    min_count                    = var.system_pool.min_count
    max_count                    = var.system_pool.max_count
    only_critical_addons_enabled = true
    os_disk_size_gb              = 64
    upgrade_settings {
      max_surge = "33%"
    }
  }

  # Azure CNI Overlay + Cilium (NetworkPolicy denies by default, see GOP-08)
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

  # Managed Prometheus: enables the metrics agent; scrape rules and the destination live in the observability module
  monitor_metrics {}

  # A private cluster has no public endpoint, so there is nothing to restrict
  dynamic "api_server_access_profile" {
    for_each = var.private_cluster_enabled ? [] : [1]
    content {
      authorized_ip_ranges = var.authorized_ip_ranges
    }
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
  zones                 = local.zones
  auto_scaling_enabled  = true
  min_count             = var.apps_pool.min_count
  max_count             = var.apps_pool.max_count
  os_disk_size_gb       = 64
  priority              = var.apps_pool.spot ? "Spot" : "Regular"
  eviction_policy       = var.apps_pool.spot ? "Delete" : null
  spot_max_price        = var.apps_pool.spot ? -1 : null
  node_labels           = { "shp/pool" = "apps" }
  tags                  = var.tags

  # Azure rejects max_surge on a Spot pool ("Spot pools do not support max_surge"); a Spot pool has no surge upgrade.
  dynamic "upgrade_settings" {
    for_each = var.apps_pool.spot ? [] : [1]
    content {
      max_surge = "33%"
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "ai" {
  count                 = var.enable_ai_pool ? 1 : 0
  name                  = "ai"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.ai_pool.vm_size
  vnet_subnet_id        = var.subnet_id
  zones                 = local.zones
  auto_scaling_enabled  = true
  min_count             = var.ai_pool.min_count
  max_count             = var.ai_pool.max_count
  os_disk_size_gb       = var.ai_pool.os_disk_size_gb
  os_disk_type          = "Managed"
  gpu_driver            = var.ai_pool.gpu_driver
  max_pods              = var.ai_pool.max_pods
  node_labels           = { "shp/pool" = "ai", "shp/workload" = "ollama" }
  node_taints           = ["workload=ai:NoSchedule"]
  tags                  = var.tags

  upgrade_settings {
    max_surge = "33%"
  }
}

# Pull images from ACR with the kubelet identity (no admin user/password)
resource "azurerm_role_assignment" "acr_pull" {
  count                = var.create_role_assignments ? 1 : 0
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}
