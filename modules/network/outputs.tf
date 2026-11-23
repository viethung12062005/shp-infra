output "vnet_id" { value = azurerm_virtual_network.this.id }
output "aks_subnet_id" { value = local.subnet_ids["snet-aks"] }
output "private_endpoints_subnet_id" { value = local.subnet_ids["snet-private-endpoints"] }
output "postgres_subnet_id" { value = local.subnet_ids["snet-postgres"] }
output "private_dns_zone_ids" {
  value = { for k, v in azurerm_private_dns_zone.this : k => v.id }
}
