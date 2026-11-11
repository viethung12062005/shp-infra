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
  description = "Grafana chỉ cho đăng nhập Entra ID. Đặt false khi có mạng quản trị riêng (cần managed private endpoint)."
  type        = bool
  default     = true
}

variable "grafana_admin_principal_ids" {
  description = "Người/nhóm Entra được quản trị Grafana (SA/DevOps)."
  type        = map(string)
  default     = {}
}

variable "grafana_viewer_principal_ids" {
  description = "Người/nhóm Entra chỉ xem dashboard (dev, giảng viên)."
  type        = map(string)
  default     = {}
}

variable "action_group_id" {
  description = "Nhóm hành động nhận cảnh báo. null = chưa gắn."
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
