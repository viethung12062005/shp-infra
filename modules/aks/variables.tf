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
  description = <<-EOT
    Tainted node pool for ai-service and Ollama. It scales to zero when idle and carries a large OS disk for the
    container images and model cache. Use a GPU SKU (for example Standard_NC4as_T4_v3) with gpu_driver = "Install"
    when GPU inference is required; the default CPU SKU fits bge-m3 + qwen2.5-7b (ADR-0013).
  EOT
  type = object({
    vm_size         = string
    min_count       = number
    max_count       = number
    os_disk_size_gb = optional(number, 256)
    gpu_driver      = optional(string, null)
    max_pods        = optional(number, 50)
  })
  default = { vm_size = "Standard_D8s_v5", min_count = 0, max_count = 2 }

  validation {
    condition     = var.ai_pool.min_count >= 0 && var.ai_pool.max_count >= var.ai_pool.min_count
    error_message = "ai_pool.min_count must be >= 0 and ai_pool.max_count must be >= ai_pool.min_count."
  }
  validation {
    condition     = var.ai_pool.gpu_driver == null || contains(["Install", "None"], var.ai_pool.gpu_driver)
    error_message = "ai_pool.gpu_driver must be null, \"Install\" or \"None\"."
  }
}

variable "acr_id" { type = string }
variable "tenant_id" { type = string }

variable "create_role_assignments" {
  description = <<-EOT
    Tạo role assignment của module. Đặt false ở subscription bị chặn Microsoft.Authorization/*/Write
    (sandbox FSO-SandboxOps): hạ tầng vẫn tạo được, phân quyền do tài khoản Owner chạy sau bằng
    `az role assignment create`.
  EOT
  type        = bool
  default     = true
}

variable "private_cluster_enabled" {
  description = "Make the API server private (no public endpoint). A subscription policy can require this; reach the cluster with `az aks command invoke` or from inside the VNet. When true, authorized_ip_ranges is not used."
  type        = bool
  default     = false
}

variable "local_accounts_enabled" {
  description = "Keep the cluster's local (certificate) admin accounts. Off by default (Entra ID only). Turn it on only where role assignments are blocked and the cluster would otherwise be unreachable."
  type        = bool
  default     = false
}

variable "entra_rbac_enabled" {
  description = "Integrate the cluster with Entra ID and use Azure RBAC for Kubernetes. On by default. Turn it off only together with local_accounts_enabled where role assignments are blocked."
  type        = bool
  default     = true
}

variable "system_pool_critical_addons_only" {
  description = "Taint the system pool with CriticalAddonsOnly. Turn off only in a test environment that must run command pods (az aks command invoke) on a small cluster."
  type        = bool
  default     = true
}
