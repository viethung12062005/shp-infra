output "tfstate_storage_account" {
  value = azurerm_storage_account.tfstate.name
}

output "tfstate_container" {
  value = try(azurerm_storage_container.tfstate[0].name, null)
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

output "required_role_assignments" {
  description = "Phân quyền cần có cho từng identity. Khi create_role_assignments=false, chạy các lệnh này bằng tài khoản Owner."
  value = [for ra in local.required_role_assignments : {
    identity = "id-shp-${ra.identity}"
    role     = ra.role
    scope    = ra.scope
    cli = join(" ", [
      "az role assignment create",
      "--assignee-object-id $(az identity show -g ${azurerm_resource_group.shared.name} -n id-shp-${ra.identity} --query principalId -o tsv)",
      "--assignee-principal-type ServicePrincipal",
      "--role '${ra.role}'",
      "--scope '${ra.scope}'",
    ])
  }]
}

output "state_container_needed" {
  description = "true khi container tfstate chưa được tạo (sandbox bị chặn dataActions): tạo bằng tài khoản có Storage Blob Data Contributor."
  value       = !var.manage_state_container
}
