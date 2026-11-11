variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "private_endpoints_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "log_analytics_workspace_id" { type = string }

variable "replication_type" {
  description = "LRS for test environments; ZRS (or GZRS) for prod."
  type        = string
  default     = "LRS"
}

variable "audit_retention_days" {
  description = "Immutability lock of the audit in days. Prod: 3650 (10 years, assumption BR-11); test environments: 1 so they can be destroyed."
  type        = number
  default     = 1
}

variable "audit_retention_locked" {
  description = "Locks the policy (it can no longer be shortened or removed). Prod only."
  type        = bool
  default     = false
}

variable "defender_malware_scan" {
  description = "Microsoft Defender for Storage scans uploaded documents for malware. Charged by scanned volume."
  type        = bool
  default     = false
}

# Identities granted data access (no account keys)
variable "document_writer_principal_ids" {
  description = "Read/write the documents and quarantine containers (document service)."
  type        = map(string)
  default     = {}
}

variable "kb_reader_principal_ids" {
  description = "Read/write the kb container (ai service)."
  type        = map(string)
  default     = {}
}

variable "ml_principal_ids" {
  description = "Read/write the mlops container (ml service: Parquet training snapshots)."
  type        = map(string)
  default     = {}
}

variable "audit_writer_principal_ids" {
  description = "Write to the audit container (audit service). No delete/change permission during the lock period."
  type        = map(string)
  default     = {}
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

variable "create_containers" {
  description = <<-EOT
    Tạo container qua Entra (data plane). Đặt false ở subscription không có dataActions
    (sandbox): container do tài khoản có "Storage Blob Data Contributor" tạo sau bằng az CLI.
  EOT
  type        = bool
  default     = true
}
