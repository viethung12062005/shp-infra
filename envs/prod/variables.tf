variable "subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "southeastasia"
}

variable "acr_name" {
  description = "Tên ACR từ output của bootstrap."
  type        = string
}

variable "acr_resource_group" {
  type    = string
  default = "rg-shp-shared"
}

variable "sizing" {
  description = "small hoặc prod. UAT dùng prod khi đo hiệu năng."
  type        = string
  default     = "prod"
}

variable "created_at" {
  description = "YYYY-MM-DD, do workflow truyền vào."
  type        = string
}

variable "ttl_hours" {
  type    = number
  default = 6
}

variable "enable_ai_pool" {
  type    = bool
  default = true
}

variable "authorized_ip_ranges" {
  description = "CIDR được gọi API server AKS (ví dụ IP công khai của SA/32). Bắt buộc."
  type        = list(string)
}
