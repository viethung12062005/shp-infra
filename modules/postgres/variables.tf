variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "tenant_id" { type = string }

variable "delegated_subnet_id" {
  description = "Subnet delegated to PostgreSQL Flexible Server (the server lives in the VNet and has no public address)."
  type        = string
}

variable "private_dns_zone_id" { type = string }

variable "entra_admin" {
  description = "Entra ID administrator of the server (the identity that runs Terraform/migrations). No password is used."
  type = object({
    object_id = string
    name      = string
    type      = string # User | Group | ServicePrincipal
  })
}

variable "sku_name" {
  description = "B_Standard_B1ms for test environments; GP_Standard_D2ds_v5 or larger for performance measurement and prod."
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
  description = "ZoneRedundant for prod; null = off."
  type        = string
  default     = null
  validation {
    condition     = var.high_availability == null || contains(["ZoneRedundant", "SameZone"], coalesce(var.high_availability, "ZoneRedundant"))
    error_message = "high_availability must be null, ZoneRedundant or SameZone."
  }
}

variable "databases" {
  description = "Databases created up front. ADR-0014: PostgreSQL now serves scheduling only."
  type        = list(string)
  default     = ["scheduling"]
}

variable "log_analytics_workspace_id" { type = string }

variable "create_entra_admin" {
  description = <<-EOT
    Gán quản trị viên Entra cho PostgreSQL. Cần quyền microsoft.aadiam/*/write (hoặc vai trò Entra
    phù hợp); sandbox cấm ghi aadiam nên đặt false và gán bằng tài khoản có quyền.
  EOT
  type        = bool
  default     = true
}
