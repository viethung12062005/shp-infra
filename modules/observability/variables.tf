variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "resource_group_id" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

variable "aks_id" { type = string }
variable "aks_name" { type = string }
variable "monitor_workspace_id" { type = string }
variable "log_analytics_workspace_id" { type = string }

variable "apps_namespace" {
  type    = string
  default = "shp-apps"
}

variable "grafana_major_version" {
  type    = string
  default = "11"
}

variable "grafana_public_network_access" {
  description = "Grafana only allows Entra ID sign-in. Set false when a dedicated admin network exists (needs a managed private endpoint)."
  type        = bool
  default     = true
}

variable "grafana_admin_principal_ids" {
  description = "Entra users/groups that administer Grafana (SA/DevOps)."
  type        = map(string)
  default     = {}
}

variable "grafana_viewer_principal_ids" {
  description = "Entra users/groups that can only view dashboards (devs, lecturers)."
  type        = map(string)
  default     = {}
}

variable "action_group_id" {
  description = "Action group that receives the alerts. null = not attached yet."
  type        = string
  default     = null
}
