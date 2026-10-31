variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "private_endpoints_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }

variable "compute_tier" {
  description = "M10 cho môi trường thử; M30 trở lên cho prod/đo hiệu năng."
  type        = string
  default     = "M10"
}

variable "storage_size_in_gb" {
  type    = number
  default = 32
}

variable "mongo_version" {
  type    = string
  default = "7.0"
}

variable "high_availability_mode" {
  description = "Disabled cho môi trường thử; ZoneRedundantPreferred cho prod."
  type        = string
  default     = "Disabled"
}

variable "service_users" {
  description = <<-EOT
    Mỗi service một danh tính Entra (workload identity) và chỉ được ghi vào database của chính nó (ADR-0014).
    Khóa = tên service, object_id = principal của managed identity, databases = database được cấp readWrite.
  EOT
  type = map(object({
    object_id = string
    databases = list(string)
  }))
}
