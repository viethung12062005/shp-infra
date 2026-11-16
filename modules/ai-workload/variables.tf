variable "enabled" {
  description = "Create the PVC and SecretProviderClass. false keeps the module inert during the first apply, when no kubeconfig exists yet."
  type        = bool
  default     = false
}

variable "kubeconfig_path" {
  description = <<-EOT
    Kubeconfig of the AKS cluster. This module is a second-phase apply: the Kubernetes provider configuration cannot
    depend on a cluster created in the same Terraform run, so it runs after the environment exists.
  EOT
  type        = string
  default     = null
}

variable "ollama_namespace" {
  description = "Namespace that runs Ollama; the model cache PVC lives here."
  type        = string
  default     = "shp-deps"
}

variable "ai_namespace" {
  description = "Namespace that runs the ai service; the Key Vault SecretProviderClass lives here."
  type        = string
  default     = "shp-apps"
}

variable "model_cache_size" {
  description = "Size of the Ollama model cache (bge-m3 + qwen2.5-7b)."
  type        = string
  default     = "100Gi"
}

variable "storage_class_name" {
  description = "AKS default Azure Disk class; managed-csi is present on every AKS cluster."
  type        = string
  default     = "managed-csi"
}

variable "key_vault_name" { type = string }
variable "tenant_id" { type = string }

variable "ai_client_id" {
  description = "Client id of the ai workload identity; the Secrets Store CSI driver uses it to read the vault."
  type        = string
}

variable "key_vault_secret_names" {
  description = "Key Vault secret names exposed to the ai pod. The values never appear in Terraform or values files."
  type        = list(string)
  default     = ["deepseek-api-key", "gemini-api-key"]
}

variable "secret_provider_class_name" {
  type    = string
  default = "ai-llm-keys"
}
