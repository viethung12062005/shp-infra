output "principal_ids" {
  description = "service -> principal (object) id, used for data role assignments."
  value       = { for k, v in azurerm_user_assigned_identity.this : k => v.principal_id }
}

output "client_ids" {
  description = "service -> clientId, goes into workloadIdentity.clientId of the chart."
  value       = { for k, v in azurerm_user_assigned_identity.this : k => v.client_id }
}

output "names" {
  description = "service -> managed identity name, which is the PostgreSQL (Entra) login of the service."
  value       = { for k, v in azurerm_user_assigned_identity.this : k => v.name }
}
