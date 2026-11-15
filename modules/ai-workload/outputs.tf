output "model_cache_pvc_name" {
  value = var.enabled ? kubernetes_persistent_volume_claim.ollama_models[0].metadata[0].name : null
}

output "model_cache_pvc_namespace" {
  value = var.enabled ? kubernetes_persistent_volume_claim.ollama_models[0].metadata[0].namespace : null
}

output "secret_provider_class_name" {
  value = var.enabled ? var.secret_provider_class_name : null
}

output "key_vault_secret_keys" {
  description = "Keys the CSI driver mounts from Key Vault into the ai pod."
  value       = var.key_vault_secret_names
}
