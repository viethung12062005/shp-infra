variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

variable "kubernetes_version" {
  description = "Để null để dùng bản mặc định được hỗ trợ của Azure; ghim khi cần."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "Free (UAT) hoặc Standard (prod, có SLA)."
  type        = string
  default     = "Free"
  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier phải là Free hoặc Standard."
  }
}

variable "zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}

variable "subnet_id" { type = string }
variable "log_analytics_workspace_id" { type = string }

variable "authorized_ip_ranges" {
  description = "Dải IP (CIDR) được gọi API server của AKS. Bắt buộc, không được rỗng hoặc 0.0.0.0/0."
  type        = list(string)
  validation {
    condition     = length(var.authorized_ip_ranges) > 0 && !contains(var.authorized_ip_ranges, "0.0.0.0/0")
    error_message = "authorized_ip_ranges phải có ít nhất một dải CIDR và không được là 0.0.0.0/0."
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
  description = "Node pool riêng cho ai-service/ollama (có taint)."
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
