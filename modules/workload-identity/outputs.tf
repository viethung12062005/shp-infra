output "principal_ids" {
  description = "service -> principal (object) id, dùng cho phân quyền dữ liệu."
  value       = { for k, v in azurerm_user_assigned_identity.this : k => v.principal_id }
}

output "client_ids" {
  description = "service -> clientId, đặt vào workloadIdentity.clientId của chart."
  value       = { for k, v in azurerm_user_assigned_identity.this : k => v.client_id }
}
