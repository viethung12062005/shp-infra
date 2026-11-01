output "id" { value = azurerm_postgresql_flexible_server.this.id }
output "name" { value = azurerm_postgresql_flexible_server.this.name }
output "fqdn" { value = azurerm_postgresql_flexible_server.this.fqdn }
output "databases" { value = [for d in azurerm_postgresql_flexible_server_database.this : d.name] }
