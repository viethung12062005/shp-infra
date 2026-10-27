# Tài nguyên THƯỜNG TRỰC (rẻ, không chứa dữ liệu bệnh nhân): state, ACR, identity cho GitHub OIDC, ngân sách.
# Chạy MỘT lần bằng tay bởi SA; sau đó chuyển state vào chính storage account này (xem README).

data "azurerm_client_config" "current" {}

locals {
  tags = merge({ "shp-scope" = "bootstrap", "managed-by" = "terraform" }, var.tags)
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_resource_group" "shared" {
  name     = "rg-shp-shared"
  location = var.location
  tags     = local.tags
}

# ---------- Terraform state ----------
resource "azurerm_storage_account" "tfstate" {
  name                            = "stshptfstate${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.shared.name
  location                        = azurerm_resource_group.shared.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
  tags                            = local.tags

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# ---------- Container registry ----------
resource "azurerm_container_registry" "acr" {
  name                = "acrshp${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  sku                 = "Standard"
  admin_enabled       = false
  tags                = local.tags
}

# ---------- Identity cho GitHub Actions (OIDC, không secret) ----------
locals {
  github_issuer = "https://token.actions.githubusercontent.com"
  identities = {
    # quyền đọc để chạy plan trong pull request
    "ci-plan" = { subject = "repo:${var.github_owner}/${var.infra_repo}:pull_request" }
    # dựng/hủy môi trường: chỉ khi job chạy trong GitHub Environment tương ứng (đã có người duyệt)
    "infra-uat"          = { subject = "repo:${var.github_owner}/${var.infra_repo}:environment:infra-uat" }
    "infra-uat-destroy"  = { subject = "repo:${var.github_owner}/${var.infra_repo}:environment:infra-uat-destroy" }
    "infra-prod"         = { subject = "repo:${var.github_owner}/${var.infra_repo}:environment:infra-prod" }
    "infra-prod-destroy" = { subject = "repo:${var.github_owner}/${var.infra_repo}:environment:infra-prod-destroy" }
    # đẩy image: chỉ từ nhánh main của repo ứng dụng
    "acr-push" = { subject = "repo:${var.github_owner}/${var.app_repo}:ref:refs/heads/main" }
  }
}

resource "azurerm_user_assigned_identity" "github" {
  for_each            = local.identities
  name                = "id-shp-${each.key}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "github" {
  for_each            = local.identities
  name                = "github-${each.key}"
  resource_group_name = azurerm_resource_group.shared.name
  parent_id           = azurerm_user_assigned_identity.github[each.key].id
  issuer              = local.github_issuer
  subject             = each.value.subject
  audience            = ["api://AzureADTokenExchange"]
}

# Quyền tối thiểu
resource "azurerm_role_assignment" "acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.github["acr-push"].principal_id
}

resource "azurerm_role_assignment" "state_rw" {
  for_each = toset(["infra-uat", "infra-uat-destroy", "infra-prod", "infra-prod-destroy", "ci-plan"])

  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.github[each.key].principal_id
}

resource "azurerm_role_assignment" "plan_reader" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.github["ci-plan"].principal_id
}

# Identity dựng môi trường cần tạo tài nguyên + gán quyền (RBAC): Contributor + User Access Administrator
# giới hạn ở subscription; thu hẹp theo resource group khi môi trường đã được tách subscription (NFR-D4).
resource "azurerm_role_assignment" "infra_contributor" {
  for_each = toset(["infra-uat", "infra-uat-destroy", "infra-prod", "infra-prod-destroy"])

  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github[each.key].principal_id
}

resource "azurerm_role_assignment" "infra_rbac_admin" {
  for_each = toset(["infra-uat", "infra-uat-destroy", "infra-prod", "infra-prod-destroy"])

  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.github[each.key].principal_id
}

# ---------- Ngân sách ----------
resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "budget-shp-monthly"
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = var.monthly_budget_usd
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  dynamic "notification" {
    for_each = toset([50, 80, 100])
    content {
      enabled        = true
      threshold      = notification.value
      operator       = "GreaterThan"
      threshold_type = "Actual"
      contact_emails = var.budget_alert_emails
    }
  }
}
