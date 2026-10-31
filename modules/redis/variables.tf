variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "private_endpoints_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }

variable "sku_name" {
  description = "Balanced_B0 cho môi trường thử; Balanced_B5 trở lên cho prod."
  type        = string
  default     = "Balanced_B0"
}

variable "high_availability_enabled" {
  type    = bool
  default = false
}

variable "client_principal_ids" {
  description = "Danh tính được đọc/ghi Redis qua Entra ID (gateway: đếm giới hạn tốc độ; scheduling: cache slot trống)."
  type        = map(string)
}
