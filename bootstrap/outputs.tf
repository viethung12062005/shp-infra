output "tfstate_storage_account" {
  value = azurerm_storage_account.tfstate.name
}

output "tfstate_container" {
  value = azurerm_storage_container.tfstate.name
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "acr_id" {
  value = azurerm_container_registry.acr.id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "github_identity_client_ids" {
  description = "Đặt làm variable (không phải secret) AZURE_CLIENT_ID_<TÊN> ở GitHub."
  value       = { for k, v in azurerm_user_assigned_identity.github : k => v.client_id }
}
