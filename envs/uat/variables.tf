variable "subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "southeastasia"
}

variable "acr_name" {
  description = "ACR name from the bootstrap output."
  type        = string
}

variable "acr_resource_group" {
  type    = string
  default = "rg-shp-shared"
}

variable "sizing" {
  description = "small or prod. UAT uses prod when measuring performance."
  type        = string
  default     = "small"
}

variable "created_at" {
  description = "YYYY-MM-DD, passed in by the workflow."
  type        = string
}

variable "ttl_hours" {
  type    = number
  default = 8
}

variable "enable_ai_pool" {
  type    = bool
  default = true
}

variable "enable_malware_scan" {
  description = "Defender for Storage malware scanning and Event Grid routing to the document queue. Charged per scanned GB, capped."
  type        = bool
  default     = true
}

variable "enable_ai_workload" {
  description = "Create the Ollama model-cache PVC and the ai CSI SecretProviderClass. Needs a kubeconfig, so it runs as a second apply after the cluster exists."
  type        = bool
  default     = false
}

variable "kubeconfig_path" {
  description = "Kubeconfig path used by the ai-workload module; only needed when enable_ai_workload is true."
  type        = string
  default     = null
}

variable "authorized_ip_ranges" {
  description = "CIDRs allowed to call the AKS API server (for example the SA's public IP/32). Required."
  type        = list(string)
}

variable "messaging_sku" {
  description = "Premium (private endpoint) or Standard (cheaper, public endpoint with Entra ID only)."
  type        = string
  default     = "Premium"
}

variable "grafana_admin_principal_ids" {
  description = "Name -> object id of the Entra users/groups that administer Grafana."
  type        = map(string)
  default     = {}
}

variable "grafana_viewer_principal_ids" {
  description = "Name -> object id of the Entra users/groups that can only view Grafana."
  type        = map(string)
  default     = {}
}

variable "create_role_assignments" {
  description = "false ở subscription bị chặn Microsoft.Authorization/*/Write (sandbox)."
  type        = bool
  default     = true
}

variable "create_containers" {
  description = "false ở subscription không có dataActions của Storage (sandbox)."
  type        = bool
  default     = true
}

variable "create_entra_admin" {
  description = "false khi không có quyền ghi microsoft.aadiam (sandbox)."
  type        = bool
  default     = true
}

variable "create_tag_policy" {
  description = "Assign the required-tag policies at the environment resource group scope. Set false when Microsoft.Authorization/*/Write is blocked (sandbox)."
  type        = bool
  default     = true
}

variable "extra_tags" {
  description = "Extra tags required by the subscription's tag policy; see modules/environment."
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

variable "aks_zones" {
  description = "Availability zones for the AKS node pools; [] where the subscription has none. See modules/environment."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "aks_system_pool_critical_addons_only" {
  description = "Taint the AKS system pool with CriticalAddonsOnly (default). Off only in a test environment."
  type        = bool
  default     = true
}

variable "storage_shared_key_enabled" {
  description = "Allow shared-key access on the storage accounts (default off, Entra ID only)."
  type        = bool
  default     = false
}

variable "redis_access_keys_enabled" {
  description = "Allow access-key authentication on Redis (default off, Entra ID only)."
  type        = bool
  default     = false
}

variable "entra_admin_name" {
  description = "Principal name of the PostgreSQL Entra administrator: the managed identity that runs Terraform, or the user's UPN when a person runs it."
  type        = string
  default     = "id-shp-infra-uat"
}

variable "entra_admin_type" {
  description = "ServicePrincipal (managed identity, the CI default) or User (a person running Terraform). It must match the object id of the caller."
  type        = string
  default     = "ServicePrincipal"
  validation {
    condition     = contains(["ServicePrincipal", "User", "Group"], var.entra_admin_type)
    error_message = "entra_admin_type must be ServicePrincipal, User or Group."
  }
}
