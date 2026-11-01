variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "private_endpoints_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }

variable "sku" {
  description = "basic cho môi trường thử; standard khi cần nhiều replica/phân vùng."
  type        = string
  default     = "basic"
}

variable "replica_count" {
  type    = number
  default = 1
}

variable "semantic_search_sku" {
  description = "null = tắt xếp hạng ngữ nghĩa (không tốn phí); free hoặc standard để bật."
  type        = string
  default     = null
}

variable "index_contributor_principal_ids" {
  description = "Đọc/ghi dữ liệu trong index (ai service)."
  type        = map(string)
  default     = {}
}

variable "service_contributor_principal_ids" {
  description = "Tạo/sửa index (job triển khai). Không cấp cho service chạy thường xuyên."
  type        = map(string)
  default     = {}
}
