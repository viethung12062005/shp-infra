output "resource_group_name" { value = azurerm_resource_group.this.name }
output "aks_name" { value = module.aks.name }
output "aks_oidc_issuer_url" { value = module.aks.oidc_issuer_url }
output "key_vault_name" { value = module.keyvault.name }
output "log_analytics_workspace_id" { value = module.monitoring.log_analytics_workspace_id }
