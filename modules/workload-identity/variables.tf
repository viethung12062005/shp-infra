variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "oidc_issuer_url" { type = string }

variable "namespace" {
  description = "Namespace chạy các service ứng dụng (khớp appsNamespace của shp-baseline)."
  type        = string
  default     = "shp-apps"
}

variable "services" {
  description = "Tên service; cũng là tên ServiceAccount."
  type        = list(string)
}
