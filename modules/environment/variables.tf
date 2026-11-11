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
