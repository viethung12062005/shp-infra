variable "environment" {
  type = string
  validation {
    condition     = contains(["uat", "prod"], var.environment)
    error_message = "environment phải là uat hoặc prod."
  }
}

variable "location" { type = string }
variable "tenant_id" { type = string }
variable "acr_id" { type = string }

variable "sizing" {
  description = "small: thử tích hợp (rẻ). prod: cỡ production, dùng khi đo hiệu năng/demo."
  type        = string
  default     = "small"
  validation {
    condition     = contains(["small", "prod"], var.sizing)
    error_message = "sizing phải là small hoặc prod."
  }
}

variable "address_space" { type = string }

variable "created_at" {
  description = "Ngày dựng (YYYY-MM-DD), do workflow truyền vào để plan không đổi mỗi lần chạy."
  type        = string
}

variable "ttl_hours" {
  description = "Môi trường nên được hủy sau số giờ này (cost-guard cảnh báo khi quá hạn)."
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
  description = "Quản trị viên Entra ID của PostgreSQL (danh tính chạy Terraform và migration). Máy chủ không có mật khẩu."
  type = object({
    object_id = string
    name      = string
    type      = string
  })
}

variable "messaging_sku" {
  description = "Premium (private endpoint, ~0,9 USD/giờ/đơn vị, môi trường thử chỉ sống vài giờ) hoặc Standard (rẻ, cổng công khai chỉ Entra ID)."
  type        = string
  default     = "Premium"
}

variable "grafana_admin_principal_ids" {
  description = "Người/nhóm Entra quản trị Grafana."
  type        = map(string)
  default     = {}
}

variable "grafana_viewer_principal_ids" {
  description = "Người/nhóm Entra chỉ xem dashboard Grafana."
  type        = map(string)
  default     = {}
}
