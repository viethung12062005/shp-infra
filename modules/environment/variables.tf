variable "environment" {
  type = string
  validation {
    condition     = contains(["uat", "prod"], var.environment)
    error_message = "environment must be uat or prod."
  }
}

variable "location" { type = string }
variable "tenant_id" { type = string }
variable "acr_id" { type = string }

variable "sizing" {
  description = "small: integration testing (cheap). prod: production size, used for performance measurement and demos."
  type        = string
  default     = "small"
  validation {
    condition     = contains(["small", "prod"], var.sizing)
    error_message = "sizing must be small or prod."
  }
}

variable "address_space" { type = string }

variable "created_at" {
  description = "Provisioning date (YYYY-MM-DD), passed in by the workflow so the plan does not change on every run."
  type        = string
}

variable "ttl_hours" {
  description = "The environment should be destroyed after this many hours (cost-guard warns when it is overdue)."
  type        = number
  default     = 8
}

variable "enable_ai_pool" {
  type    = bool
  default = true
}

variable "enable_malware_scan" {
  description = "Microsoft Defender for Storage scans new documents and routes results to the document queue (charged per scanned GB, capped)."
  type        = bool
  default     = true
}

variable "enable_ai_workload" {
  description = "Create the Ollama model-cache PVC and the ai Key Vault SecretProviderClass. Requires a kubeconfig, so it runs as a second apply after the cluster exists."
  type        = bool
  default     = false
}

variable "kubeconfig_path" {
  description = "Path to a kubeconfig that can reach the provisioned cluster; used only when enable_ai_workload is true."
  type        = string
  default     = null
}

variable "ai_model_cache_size" {
  description = "Size of the Ollama model cache PVC (bge-m3 + qwen2.5-7b)."
  type        = string
  default     = "100Gi"
}

variable "ai_key_vault_secret_names" {
  description = "Key Vault secret names mounted into the ai pod through the Secrets Store CSI driver. The values stay only in Key Vault."
  type        = list(string)
  default     = ["deepseek-api-key", "gemini-api-key"]
}

variable "authorized_ip_ranges" {
  type = list(string)
}

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "entra_admin" {
  description = "Entra ID administrator of PostgreSQL (the identity that runs Terraform and migrations). The server has no password."
  type = object({
    object_id = string
    name      = string
    type      = string
  })
}

variable "messaging_sku" {
  description = "Premium (private endpoint, ~0.9 USD/hour/unit; a test environment only lives a few hours) or Standard (cheap, public endpoint with Entra ID only)."
  type        = string
  default     = "Premium"
}

variable "grafana_admin_principal_ids" {
  description = "Entra users/groups that administer Grafana."
  type        = map(string)
  default     = {}
}

variable "grafana_viewer_principal_ids" {
  description = "Entra users/groups that can only view the Grafana dashboards."
  type        = map(string)
  default     = {}
}

variable "create_role_assignments" {
  description = <<-EOT
    Tạo role assignment của các module (AKS AcrPull, Grafana đọc metric, Service Bus/Search/Storage data roles).
    Đặt false ở subscription bị chặn Microsoft.Authorization/*/Write; phân quyền do Owner chạy sau.
  EOT
  type        = bool
  default     = true
}

variable "create_containers" {
  description = "Tạo container Blob qua Entra (cần dataActions). Đặt false ở sandbox và tạo bằng az CLI."
  type        = bool
  default     = true
}

variable "create_entra_admin" {
  description = "Gán quản trị viên Entra cho PostgreSQL (cần microsoft.aadiam/*/write)."
  type        = bool
  default     = true
}

variable "create_tag_policy" {
  description = <<-EOT
    Assign the required-tag policies (shp-env, created-at, ttl-hours) at the environment resource group scope.
    Set false where Microsoft.Authorization/*/Write is blocked (sandbox); the policy assignments are then skipped.
  EOT
  type        = bool
  default     = true
}

variable "keycloak_db_auth" {
  description = "How Keycloak signs in to its PostgreSQL server: password (generated, kept only in Key Vault) or entra (workload identity). Settled in IAM-01."
  type        = string
  default     = "password"
}

variable "create_key_vault_secrets" {
  description = "Write the generated Keycloak secrets into Key Vault through an ARM deployment. Set false if the deploying identity cannot write vault secrets."
  type        = bool
  default     = true
}

variable "extra_tags" {
  description = "Extra tags added to every resource group and resource, for subscriptions whose tag policy requires more than the shp-* tags (for example Environment, Region, CreatedBy, Description and ServiceOwner). Empty by default."
  type        = map(string)
  default     = {}
}

variable "aks_private_cluster" {
  description = "Make the AKS API server private. Needed where a subscription policy requires private clusters."
  type        = bool
  default     = false
}

variable "aks_local_accounts_enabled" {
  description = "Keep AKS local admin accounts (default off, Entra ID only). For subscriptions where role assignments are blocked."
  type        = bool
  default     = false
}

variable "aks_entra_rbac_enabled" {
  description = "Entra ID integration with Azure RBAC for Kubernetes (default on). Turn off only together with aks_local_accounts_enabled."
  type        = bool
  default     = true
}
