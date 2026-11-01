# Azure Managed Redis cho giới hạn tốc độ ở gateway và cache slot trống (TTL 5 giây). Dữ liệu chỉ là bản sao, mất không sao
# (đọc thẳng DB), nên không bật persistence. Tắt khóa truy cập: chỉ Entra ID, chỉ private endpoint.
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_managed_redis" "this" {
  name                = "redis-${var.name_prefix}-${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = var.sku_name
  tags                = var.tags

  high_availability_enabled = var.high_availability_enabled
  public_network_access     = "Disabled"

  default_database {
    access_keys_authentication_enabled = false
    client_protocol                    = "Encrypted"
    clustering_policy                  = "EnterpriseCluster"
    eviction_policy                    = "VolatileLRU"
  }
}

module "private_endpoint" {
  source              = "../private-endpoint"
  name                = "pe-${azurerm_managed_redis.this.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  subnet_id           = var.private_endpoints_subnet_id
  target_resource_id  = azurerm_managed_redis.this.id
  subresource         = "redisEnterprise"
  private_dns_zone_id = var.private_dns_zone_id
}

resource "azurerm_managed_redis_access_policy_assignment" "client" {
  for_each = var.client_principal_ids

  managed_redis_id = azurerm_managed_redis.this.id
  object_id        = each.value
}
