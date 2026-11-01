output "docs_account_name" { value = azurerm_storage_account.this["docs"].name }
output "audit_account_name" { value = azurerm_storage_account.this["audit"].name }
output "docs_blob_endpoint" { value = azurerm_storage_account.this["docs"].primary_blob_endpoint }
output "audit_blob_endpoint" { value = azurerm_storage_account.this["audit"].primary_blob_endpoint }
