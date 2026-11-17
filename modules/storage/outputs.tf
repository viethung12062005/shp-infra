output "docs_account_id" { value = azurerm_storage_account.this["docs"].id }
output "docs_account_name" { value = azurerm_storage_account.this["docs"].name }
output "audit_account_name" { value = azurerm_storage_account.this["audit"].name }
output "docs_blob_endpoint" { value = azurerm_storage_account.this["docs"].primary_blob_endpoint }
output "audit_blob_endpoint" { value = azurerm_storage_account.this["audit"].primary_blob_endpoint }
output "kb_container_name" {
  description = "Actual name of the knowledge-base container; set it as the ai service kb_container setting in shp-gitops."
  value       = local.docs_container_names["kb"]
}
