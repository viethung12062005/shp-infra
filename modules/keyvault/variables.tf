variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "tenant_id" { type = string }

variable "purge_protection_enabled" {
  description = "Bật ở prod. Tắt ở UAT để dựng lại/hủy môi trường được."
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  type    = number
  default = 7
}

variable "private_endpoints_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
