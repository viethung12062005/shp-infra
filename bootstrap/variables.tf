variable "subscription_id" {
  description = "Subscription chứa tài nguyên thường trực (state, ACR, identity)."
  type        = string
}

variable "location" {
  type    = string
  default = "southeastasia"
}

variable "github_owner" {
  description = "Tài khoản/tổ chức GitHub sở hữu các repo."
  type        = string
}

variable "app_repo" {
  type    = string
  default = "smart-hospital-platform"
}

variable "infra_repo" {
  type    = string
  default = "shp-infra"
}

variable "templates_repo" {
  type    = string
  default = "shp-platform-templates"
}

variable "budget_alert_emails" {
  description = "Email nhận cảnh báo ngân sách."
  type        = list(string)
}

variable "monthly_budget_usd" {
  description = "Ngân sách tháng cho toàn subscription (do PM chốt)."
  type        = number
}

variable "budget_start_date" {
  description = "Ngày đầu tháng bắt đầu áp dụng ngân sách, dạng 2026-11-01T00:00:00Z."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "create_role_assignments" {
  description = <<-EOT
    Tạo role assignment cho các identity GitHub. Đặt false ở môi trường mà tài khoản chạy Terraform bị chặn
    Microsoft.Authorization/*/Write (ví dụ sandbox FSO-SandboxOps, cấm mọi thao tác ghi phân quyền).
    Khi false, output required_role_assignments liệt kê đúng lệnh az cần chạy bằng tài khoản có quyền Owner.
  EOT
  type        = bool
  default     = true
}

variable "manage_state_container" {
  description = <<-EOT
    Tạo container "tfstate". Container đi qua data plane nên cần dataActions của Storage (Storage Blob Data
    Contributor); sandbox chỉ có actions "*" nên đặt false và tạo container bằng tài khoản có quyền dữ liệu.
  EOT
  type        = bool
  default     = true
}

variable "acr_sku" {
  description = <<-EOT
    SKU của Azure Container Registry. Basic (~5 USD/tháng) đủ cho CI đẩy image và chart OCI; retention policy
    cho image không gắn tag là tính năng Premium (IAC-02 để lại khi nâng SKU). Standard ~20 USD/tháng.
  EOT
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku phải là Basic, Standard hoặc Premium."
  }
}
