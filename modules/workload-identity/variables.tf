variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "oidc_issuer_url" { type = string }

variable "namespace" {
  description = "Namespace that runs the application services (matches appsNamespace of shp-baseline)."
  type        = string
  default     = "shp-apps"
}

variable "services" {
  description = "Service name; also the ServiceAccount name."
  type        = list(string)
}
