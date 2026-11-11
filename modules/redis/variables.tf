variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "private_endpoints_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }

variable "sku_name" {
  description = "Balanced_B0 for test environments; Balanced_B5 or larger for prod."
  type        = string
  default     = "Balanced_B0"
}

variable "high_availability_enabled" {
  type    = bool
  default = false
}

variable "client_principal_ids" {
  description = "Identities allowed to read/write Redis through Entra ID (gateway: rate-limit counters; scheduling: free-slot cache)."
  type        = map(string)
}
