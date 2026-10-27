resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

# Tên có hậu tố ngẫu nhiên: Key Vault đã xóa mềm vẫn giữ tên, nên dựng lại môi trường sẽ không đụng tên cũ.
resource "azurerm_key_vault" "this" {
  name                          = substr("kv-${var.name_prefix}-${random_string.suffix.result}", 0, 24)
  resource_group_name           = var.resource_group_name
  location                      = var.location
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days
  public_network_access_enabled = false
  tags                          = var.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

resource "azurerm_private_endpoint" "this" {
  name                = "pe-${azurerm_key_vault.this.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoints_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "kv"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}
