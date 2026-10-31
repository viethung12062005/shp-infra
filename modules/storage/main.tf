# Hai storage account (05-storage-audit-blob.md): tài liệu lâm sàng và audit bất biến. Tắt khóa chung, chỉ Entra ID,
# chỉ truy cập qua private endpoint.
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

locals {
  # Tên storage account: 3-24 ký tự, chữ thường và số
  account_names = {
    docs  = "stshpdocs${random_string.suffix.result}${substr(sha1(var.name_prefix), 0, 6)}"
    audit = "stshpaudit${random_string.suffix.result}${substr(sha1(var.name_prefix), 0, 6)}"
  }
}

resource "azurerm_storage_account" "this" {
  for_each = local.account_names

  name                     = each.value
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"
  tags                     = var.tags

  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  public_network_access_enabled     = false
  cross_tenant_replication_enabled  = false
  infrastructure_encryption_enabled = each.key == "audit"

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  blob_properties {
    # docs: lưu phiên bản + xóa mềm 14 ngày. audit: chống sửa/xóa bằng chính sách bất biến, không bật versioning.
    versioning_enabled = each.key == "docs"

    dynamic "delete_retention_policy" {
      for_each = each.key == "docs" ? [1] : []
      content {
        days = 14
      }
    }

    dynamic "container_delete_retention_policy" {
      for_each = each.key == "docs" ? [1] : []
      content {
        days = 14
      }
    }
  }
}

module "private_endpoint" {
  for_each = azurerm_storage_account.this

  source              = "../private-endpoint"
  name                = "pe-${each.value.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  subnet_id           = var.private_endpoints_subnet_id
  target_resource_id  = each.value.id
  subresource         = "blob"
  private_dns_zone_id = var.private_dns_zone_id
}

# ---- containers
resource "azurerm_storage_container" "docs" {
  for_each = toset(["documents", "quarantine", "kb", "mlops"])

  name                  = each.value
  storage_account_id    = azurerm_storage_account.this["docs"].id
  container_access_type = "private"

  depends_on = [module.private_endpoint]
}

resource "azurerm_storage_container" "audit" {
  name                  = "audit"
  storage_account_id    = azurerm_storage_account.this["audit"].id
  container_access_type = "private"

  depends_on = [module.private_endpoint]
}

# WORM: bản gốc audit không ai xóa/sửa được trong thời gian khóa (kể cả Owner), vẫn nối thêm được (append blob).
resource "azurerm_storage_container_immutability_policy" "audit" {
  storage_container_resource_manager_id = azurerm_storage_container.audit.id
  immutability_period_in_days           = var.audit_retention_days
  protected_append_writes_all_enabled   = true
  locked                                = var.audit_retention_locked
}

# Tầng Hot -> Cool 30 ngày -> Cold 180 ngày cho tài liệu (ADR-0014, mục tối ưu Blob)
resource "azurerm_storage_management_policy" "docs" {
  storage_account_id = azurerm_storage_account.this["docs"].id

  rule {
    name    = "tier-documents"
    enabled = true
    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["documents/"]
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
        tier_to_cold_after_days_since_modification_greater_than = 180
      }
    }
  }
}

resource "azurerm_security_center_storage_defender" "docs" {
  count = var.defender_malware_scan ? 1 : 0

  storage_account_id                          = azurerm_storage_account.this["docs"].id
  malware_scanning_on_upload_enabled          = true
  malware_scanning_on_upload_cap_gb_per_month = 100
}

# ---- quyền dữ liệu theo nguyên tắc tối thiểu, gắn ở mức container
resource "azurerm_role_assignment" "documents" {
  for_each = {
    for p in setproduct(keys(var.document_writer_principal_ids), ["documents", "quarantine"]) : "${p[0]}-${p[1]}" => { who = p[0], container = p[1] }
  }

  scope                = azurerm_storage_container.docs[each.value.container].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.document_writer_principal_ids[each.value.who]
}

resource "azurerm_role_assignment" "kb" {
  for_each = var.kb_reader_principal_ids

  scope                = azurerm_storage_container.docs["kb"].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "mlops" {
  for_each = var.ml_principal_ids

  scope                = azurerm_storage_container.docs["mlops"].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "audit" {
  for_each = var.audit_writer_principal_ids

  scope                = azurerm_storage_container.audit.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}

# Nhật ký truy cập blob (đọc/ghi/xóa) vào Log Analytics để dò truy cập bất thường
resource "azurerm_monitor_diagnostic_setting" "blob" {
  for_each = azurerm_storage_account.this

  name                       = "to-log-analytics"
  target_resource_id         = "${each.value.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "Transaction"
  }
}
