variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

variable "address_space" {
  type    = string
  default = "10.60.0.0/16"
}

variable "private_dns_zones" {
  description = "Private DNS zones for the private endpoints of the data services (added as data modules are attached)."
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

variable "private_dns_zone_tags" {
  description = "Tags for the private DNS zones. Azure allows at most 15 tags on a zone, and a tag policy can inherit about ten from the subscription, so a small set may be needed. Defaults to tags."
  type        = map(string)
  default     = null
}
