variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

variable "address_space" {
  type    = string
  default = "10.60.0.0/16"
}

variable "private_dns_zones" {
  description = "Private DNS zone cho private endpoint của các dịch vụ dữ liệu (thêm dần khi gắn module dữ liệu)."
  type        = list(string)
  default = [
    "privatelink.vaultcore.azure.net",
    "privatelink.postgres.database.azure.com",
    "privatelink.mongocluster.cosmos.azure.com",
    "privatelink.redis.azure.net",
    "privatelink.blob.core.windows.net",
    "privatelink.servicebus.windows.net",
    "privatelink.search.windows.net",
  ]
}
