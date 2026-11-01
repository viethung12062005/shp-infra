# PostgreSQL Flexible Server cho scheduling (ADR-0014). Chỉ truy cập trong VNet, chỉ đăng nhập bằng Entra ID.
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = "psql-${var.name_prefix}-${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = var.postgres_version
  sku_name            = var.sku_name
  storage_mb          = var.storage_mb
  tags                = var.tags

  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = false

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup
  auto_grow_enabled            = true

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = var.tenant_id
  }

  dynamic "high_availability" {
    for_each = var.high_availability == null ? [] : [var.high_availability]
    content {
      mode = high_availability.value
    }
  }

  lifecycle {
    ignore_changes = [zone, high_availability[0].standby_availability_zone]
  }
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "admin" {
  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  object_id           = var.entra_admin.object_id
  principal_name      = var.entra_admin.name
  principal_type      = var.entra_admin.type
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  for_each  = toset(var.databases)
  name      = each.value
  server_id = azurerm_postgresql_flexible_server.this.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# scheduling dùng btree_gist để loại trừ chồng lịch bác sĩ ở tầng CSDL (02-db-scheduling.md).
resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "BTREE_GIST"
}

# Ghi nhật ký kết nối/truy vấn để dò truy cập bất thường (NFR-SEC audit); không ghi giá trị tham số.
resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "on"
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "to-log-analytics"
  target_resource_id         = azurerm_postgresql_flexible_server.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
