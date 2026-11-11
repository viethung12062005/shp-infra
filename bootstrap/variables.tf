variable "subscription_id" {
  description = "Subscription that holds the always-on resources (state, ACR, identities)."
  type        = string
}

variable "location" {
  type    = string
  default = "southeastasia"
}

variable "github_owner" {
  description = "GitHub account/organization that owns the repos."
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

variable "templates_repo" {
  type    = string
  default = "shp-platform-templates"
}

variable "budget_alert_emails" {
  description = "Email addresses that receive budget alerts."
  type        = list(string)
}

variable "monthly_budget_usd" {
  description = "Monthly budget for the whole subscription (set by the PM)."
  type        = number
}

variable "budget_start_date" {
  description = "First day of the month the budget starts, in the form 2026-11-01T00:00:00Z."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "create_role_assignments" {
  description = <<-EOT
    Create role assignments for the GitHub identities. Set to false where the account running Terraform is blocked from
    Microsoft.Authorization/*/Write (for example the FSO-SandboxOps sandbox, which forbids every role-assignment write).
    When false, the output required_role_assignments lists the exact az commands to run with an Owner account.
  EOT
  type        = bool
  default     = true
}

variable "manage_state_container" {
  description = <<-EOT
    Create the "tfstate" container. The container goes through the data plane, so it needs Storage dataActions (Storage Blob
    Data Contributor); the sandbox only has actions "*", so set false and create the container with an account that has data access.
  EOT
  type        = bool
  default     = true
}

variable "acr_sku" {
  description = <<-EOT
    SKU of the Azure Container Registry. Basic (~5 USD/month) is enough for CI to push images and OCI charts; the retention
    policy for untagged images is a Premium feature (IAC-02 leaves it for a SKU upgrade). Standard is ~20 USD/month.
  EOT
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be Basic, Standard or Premium."
  }
}
