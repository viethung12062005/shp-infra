variable "resource_group_id" {
  description = "ID of the resource group that the required-tag policy assignments are scoped to."
  type        = string
}

variable "required_tags" {
  description = "Tags that every resource (and the resource group) in the scope must carry."
  type        = list(string)
  default     = ["shp-env", "created-at", "ttl-hours"]
}
