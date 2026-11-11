variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

variable "kubernetes_version" {
  description = "Leave null to use the Azure-supported default version; pin when needed."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "Free (UAT) or Standard (prod, with an SLA)."
  type        = string
  default     = "Free"
  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be Free or Standard."
  }
}

variable "zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}

variable "subnet_id" { type = string }
variable "log_analytics_workspace_id" { type = string }

variable "authorized_ip_ranges" {
  description = "IP ranges (CIDR) allowed to call the AKS API server. Required; must not be empty or 0.0.0.0/0."
  type        = list(string)
  validation {
    condition     = length(var.authorized_ip_ranges) > 0 && !contains(var.authorized_ip_ranges, "0.0.0.0/0")
    error_message = "authorized_ip_ranges must contain at least one CIDR range and must not be 0.0.0.0/0."
  }
}

variable "system_pool" {
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
  })
}

variable "apps_pool" {
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
    spot      = bool
  })
}

variable "enable_ai_pool" {
  description = "Dedicated node pool for ai-service/ollama (tainted)."
  type        = bool
  default     = false
}

variable "ai_pool" {
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
  })
  default = { vm_size = "Standard_D4s_v5", min_count = 0, max_count = 2 }
}

variable "acr_id" { type = string }
variable "tenant_id" { type = string }
