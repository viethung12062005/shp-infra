variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "tenant_id" { type = string }

variable "delegated_subnet_id" {
  description = "Subnet được ủy quyền cho PostgreSQL Flexible Server (máy chủ nằm trong VNet, không có địa chỉ công khai)."
  type        = string
}

variable "private_dns_zone_id" { type = string }

variable "entra_admin" {
  description = "Quản trị viên Entra ID của máy chủ (danh tính chạy Terraform/migration). Không dùng mật khẩu."
  type = object({
    object_id = string
    name      = string
    type      = string # User | Group | ServicePrincipal
  })
}

variable "sku_name" {
  description = "B_Standard_B1ms cho môi trường thử; GP_Standard_D2ds_v5 trở lên khi đo hiệu năng/prod."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  type    = number
  default = 32768
}

variable "postgres_version" {
  type    = string
  default = "16"
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "geo_redundant_backup" {
  type    = bool
  default = false
}

variable "high_availability" {
  description = "ZoneRedundant cho prod; null = tắt."
  type        = string
  default     = null
  validation {
    condition     = var.high_availability == null || contains(["ZoneRedundant", "SameZone"], coalesce(var.high_availability, "ZoneRedundant"))
    error_message = "high_availability phải là null, ZoneRedundant hoặc SameZone."
  }
}

variable "databases" {
  description = "Database tạo sẵn. ADR-0014: PostgreSQL chỉ còn phục vụ scheduling."
  type        = list(string)
  default     = ["scheduling"]
}

variable "log_analytics_workspace_id" { type = string }
