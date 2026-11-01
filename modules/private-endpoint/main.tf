# Một private endpoint + bản ghi DNS riêng. Dùng chung cho mọi dịch vụ dữ liệu để không dịch vụ nào mở ra Internet.
resource "azurerm_private_endpoint" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = var.subresource
    private_connection_resource_id = var.target_resource_id
    subresource_names              = [var.subresource]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = var.subresource
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}
