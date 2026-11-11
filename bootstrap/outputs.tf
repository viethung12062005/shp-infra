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
  description = "Set as the variable (not a secret) AZURE_CLIENT_ID_<NAME> in GitHub."
  value       = { for k, v in azurerm_user_assigned_identity.github : k => v.client_id }
}

output "required_role_assignments" {
  description = "Role assignments each identity needs. When create_role_assignments=false, run these commands with an Owner account."
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
  description = "true when the tfstate container has not been created (sandbox blocks dataActions): create it with an account that has Storage Blob Data Contributor."
  value       = !var.manage_state_container
}
