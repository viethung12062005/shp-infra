# Azure Cosmos DB for MongoDB (vCore) dùng chung cho clinical, document, ai, notification, ml (ADR-0008, ADR-0014).
# Mỗi service một database và một người dùng Entra ID riêng. Chỉ truy cập qua private endpoint.
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

# Tài khoản quản trị gốc bắt buộc khi tạo cụm. Mật khẩu chỉ nằm trong state (backend mã hóa, truy cập bằng Entra ID),
# không xuất ra output và không service nào dùng; service đăng nhập bằng Entra ID.
resource "random_password" "admin" {
  length           = 40
  special          = true
  override_special = "-_.~"
  min_upper        = 4
  min_lower        = 4
  min_numeric      = 4
  min_special      = 2
}

resource "azurerm_mongo_cluster" "this" {
  name                = "mongo-${var.name_prefix}-${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  administrator_username = "shpadmin"
  administrator_password = random_password.admin.result
  authentication_methods = ["NativeAuth", "MicrosoftEntraID"]

  compute_tier           = var.compute_tier
  high_availability_mode = var.high_availability_mode
  shard_count            = 1
  storage_size_in_gb     = var.storage_size_in_gb
  storage_type           = "PremiumSSD"
  version                = var.mongo_version

  public_network_access = "Disabled"
}

module "private_endpoint" {
  source              = "../private-endpoint"
  name                = "pe-${azurerm_mongo_cluster.this.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  subnet_id           = var.private_endpoints_subnet_id
  target_resource_id  = azurerm_mongo_cluster.this.id
  subresource         = "MongoCluster"
  private_dns_zone_id = var.private_dns_zone_id
}

resource "azurerm_mongo_cluster_user" "service" {
  for_each = var.service_users

  mongo_cluster_id       = azurerm_mongo_cluster.this.id
  object_id              = each.value.object_id
  identity_provider_type = "MicrosoftEntraID"
  principal_type         = "servicePrincipal"

  dynamic "role" {
    for_each = toset(each.value.databases)
    content {
      database = role.value
      name     = "readWrite"
    }
  }
}
