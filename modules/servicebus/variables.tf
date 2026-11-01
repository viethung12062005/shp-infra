variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "private_endpoints_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }

variable "sku" {
  description = <<-EOT
    Premium: có private endpoint (khuyến nghị, event mang mã bệnh nhân). Standard rẻ hơn nhưng không có private endpoint:
    khi đó namespace mở cổng công khai (chỉ Entra ID, TLS 1.2) và không tạo private endpoint.
  EOT
  type        = string
  default     = "Premium"
  validation {
    condition     = contains(["Premium", "Standard"], var.sku)
    error_message = "sku phải là Premium hoặc Standard."
  }
}

variable "topic_name" {
  type    = string
  default = "shp-events"
}

variable "subscriptions" {
  description = "Mỗi consumer một subscription, lọc theo thuộc tính `type` của CloudEvents (13-events.md §2)."
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
  description = "Danh tính được phát event lên topic (mọi service phát audit E11, nên thường là tất cả)."
  type        = map(string)
}

variable "receiver_principal_ids" {
  description = "Danh tính được nhận từ subscription cùng tên (khóa phải có trong `subscriptions`)."
  type        = map(string)
}

variable "log_analytics_workspace_id" { type = string }

variable "action_group_id" {
  description = "Nhóm cảnh báo cho DLQ có message (OBS-03). null = chưa tạo cảnh báo."
  type        = string
  default     = null
}
