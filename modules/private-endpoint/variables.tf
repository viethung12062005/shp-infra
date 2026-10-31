variable "name" {
  description = "Tên private endpoint (pe-...)."
  type        = string
}
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "subnet_id" { type = string }
variable "target_resource_id" { type = string }

variable "subresource" {
  description = "Loại kết nối của dịch vụ đích: vault, MongoCluster, redisEnterprise, namespace, blob, searchService..."
  type        = string
}

variable "private_dns_zone_id" { type = string }
