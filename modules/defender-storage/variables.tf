variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

variable "storage_account_id" {
  description = "Storage account whose new blobs are scanned (the documents account)."
  type        = string
}

variable "servicebus_queue_id" {
  description = "Queue that receives Microsoft.Security.MalwareScanningResult events for the document service."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace that records Event Grid delivery and publish failures."
  type        = string
}

variable "enabled" {
  description = <<-EOT
    Create Defender for Storage and the Event Grid routing. false leaves the queue in place but scans nothing,
    which is useful when the subscription has no Defender for Storage plan.
  EOT
  type        = bool
  default     = true
}

variable "malware_scanning_on_upload_cap_gb_per_month" {
  description = "Monthly cap of scanned gigabytes, so a scan flood cannot create an unbounded bill."
  type        = number
  default     = 100
}

variable "create_role_assignments" {
  description = <<-EOT
    Create the module role assignment (Event Grid identity -> Azure Service Bus Data Sender).
    Set false where Microsoft.Authorization/*/Write is blocked (sandbox); the Owner runs
    `az role assignment create` afterwards.
  EOT
  type        = bool
  default     = true
}
