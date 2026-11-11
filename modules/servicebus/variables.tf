variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "private_endpoints_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }

variable "sku" {
  description = <<-EOT
    Premium: has a private endpoint (recommended, events carry patient ids). Standard is cheaper but has no private endpoint:
    the namespace then opens a public endpoint (Entra ID only, TLS 1.2) and no private endpoint is created.
  EOT
  type        = string
  default     = "Premium"
  validation {
    condition     = contains(["Premium", "Standard"], var.sku)
    error_message = "sku must be Premium or Standard."
  }
}

variable "topic_name" {
  type    = string
  default = "shp-events"
}

variable "subscriptions" {
  description = "One subscription per consumer, filtered on the CloudEvents `type` attribute (13-events.md §2)."
  type        = map(list(string))
  default = {
    notification = [
      "shp.scheduling.appointment-booked.v1", "shp.scheduling.appointment-cancelled.v1", "shp.scheduling.appointment-rescheduled.v1",
      "shp.clinical.patient-merged.v1", "shp.document.document-released.v1", "shp.ml.no-show-scored.v1",
    ]
    ml = [
      "shp.scheduling.appointment-booked.v1", "shp.scheduling.appointment-cancelled.v1", "shp.scheduling.appointment-rescheduled.v1",
      "shp.scheduling.appointment-status-changed.v1", "shp.clinical.patient-merged.v1",
    ]
    clinical = [
      "shp.scheduling.appointment-booked.v1", "shp.scheduling.appointment-cancelled.v1", "shp.scheduling.appointment-rescheduled.v1",
      "shp.scheduling.appointment-checked-in.v1", "shp.scheduling.appointment-status-changed.v1",
    ]
    scheduling = ["shp.clinical.encounter-finished.v1", "shp.clinical.patient-merged.v1"]
    document   = ["shp.clinical.patient-merged.v1"]
    ai         = ["shp.document.document-uploaded.v1"]
    audit      = ["shp.audit.recorded.v1"]
  }
}

variable "sender_principal_ids" {
  description = "Identities allowed to publish events to the topic (every service emits audit E11, so usually all of them)."
  type        = map(string)
}

variable "receiver_principal_ids" {
  description = "Identities allowed to receive from the subscription of the same name (the key must exist in `subscriptions`)."
  type        = map(string)
}

variable "log_analytics_workspace_id" { type = string }

variable "action_group_id" {
  description = "Action group for messages in the DLQ (OBS-03). null = no alert is created."
  type        = string
  default     = null
}

variable "create_role_assignments" {
  description = <<-EOT
    Tạo role assignment của module. Đặt false ở subscription bị chặn Microsoft.Authorization/*/Write
    (sandbox FSO-SandboxOps): hạ tầng vẫn tạo được, phân quyền do tài khoản Owner chạy sau bằng
    `az role assignment create`.
  EOT
  type        = bool
  default     = true
}
