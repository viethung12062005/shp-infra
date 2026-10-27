output "resource_group_name" {
  value = module.environment.resource_group_name
}

output "aks_name" {
  value = module.environment.aks_name
}

output "aks_oidc_issuer_url" {
  value = module.environment.aks_oidc_issuer_url
}

output "key_vault_name" {
  value = module.environment.key_vault_name
}
