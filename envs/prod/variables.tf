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
  default     = "prod"
}

variable "created_at" {
  description = "YYYY-MM-DD, passed in by the workflow."
  type        = string
}

variable "ttl_hours" {
  type    = number
  default = 6
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
