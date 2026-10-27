variable "subscription_id" {
  description = "Subscription chứa tài nguyên thường trực (state, ACR, identity)."
  type        = string
}

variable "location" {
  type    = string
  default = "southeastasia"
}

variable "github_owner" {
  description = "Tài khoản/tổ chức GitHub sở hữu các repo."
  type        = string
}

variable "app_repo" {
  type    = string
  default = "smart-hospital-platform"
}

variable "infra_repo" {
  type    = string
  default = "shp-infra"
}

variable "budget_alert_emails" {
  description = "Email nhận cảnh báo ngân sách."
  type        = list(string)
}

variable "monthly_budget_usd" {
  description = "Ngân sách tháng cho toàn subscription (do PM chốt)."
  type        = number
}

variable "budget_start_date" {
  description = "Ngày đầu tháng bắt đầu áp dụng ngân sách, dạng 2026-11-01T00:00:00Z."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
