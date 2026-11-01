variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "private_endpoints_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "log_analytics_workspace_id" { type = string }

variable "replication_type" {
  description = "LRS cho môi trường thử; ZRS (hoặc GZRS) cho prod."
  type        = string
  default     = "LRS"
}

variable "audit_retention_days" {
  description = "Số ngày khóa bất biến của audit. Prod: 3650 (10 năm, giả định BR-11); môi trường thử: 1 để hủy được."
  type        = number
  default     = 1
}

variable "audit_retention_locked" {
  description = "Khóa chính sách (không thể rút ngắn hay gỡ). Chỉ bật ở prod."
  type        = bool
  default     = false
}

variable "defender_malware_scan" {
  description = "Microsoft Defender for Storage quét mã độc tài liệu tải lên. Có phí theo dung lượng quét."
  type        = bool
  default     = false
}

# Danh tính được cấp quyền dữ liệu (không dùng khóa tài khoản)
variable "document_writer_principal_ids" {
  description = "Ghi/đọc container documents và quarantine (document service)."
  type        = map(string)
  default     = {}
}

variable "kb_reader_principal_ids" {
  description = "Đọc/ghi container kb (ai service)."
  type        = map(string)
  default     = {}
}

variable "ml_principal_ids" {
  description = "Ghi/đọc container mlops (ml service: snapshot huấn luyện Parquet)."
  type        = map(string)
  default     = {}
}

variable "audit_writer_principal_ids" {
  description = "Ghi vào container audit (audit service). Không có quyền xóa/sửa trong thời gian khóa."
  type        = map(string)
  default     = {}
}
