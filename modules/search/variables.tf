variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "private_endpoints_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }

variable "sku" {
  description = "basic for test environments; standard when more replicas/partitions are needed."
  type        = string
  default     = "basic"
}

variable "replica_count" {
  type    = number
  default = 1
}

variable "semantic_search_sku" {
  description = "null = semantic ranking off (no charge); free or standard to turn it on."
  type        = string
  default     = null
}

variable "index_contributor_principal_ids" {
  description = "Read/write data in the index (ai service)."
  type        = map(string)
  default     = {}
}

variable "service_contributor_principal_ids" {
  description = "Create/change the index (deployment job). Never granted to a long-running service."
  type        = map(string)
  default     = {}
}
