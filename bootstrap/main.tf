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

# Container state tạo qua data plane (Entra) nên cần role "Storage Blob Data Contributor"; môi trường bị chặn
# Microsoft.Authorization/*/Write (sandbox) không tự cấp được role đó. Đặt manage_state_container=false và tạo
# container bằng tài khoản có quyền dữ liệu (xem README).
resource "azurerm_storage_container" "tfstate" {
  count                 = var.manage_state_container ? 1 : 0
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# ---------- Container registry ----------
resource "azurerm_container_registry" "acr" {
  name                = "acrshp${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  sku                 = var.acr_sku
  admin_enabled       = false
  tags                = local.tags
}

# ---------- Identity cho GitHub Actions (OIDC, không secret) ----------
locals {
  github_issuer = "https://token.actions.githubusercontent.com"
  identities = {
    # quyền đọc: bước plan của env-provision và cost-guard. Cả hai chạy từ nhánh main, không có Environment
    # (CI trên pull request chỉ kiểm tĩnh, không đăng nhập Azure).
    "ci-plan" = { subject = "repo:${var.github_owner}/${var.infra_repo}:ref:refs/heads/main" }
    # dựng/hủy môi trường: chỉ khi job chạy trong GitHub Environment tương ứng. Mỗi Environment bị giới hạn ở nhánh
    # main (deployment branch policy), nên nhánh khác không xin được token mang subject này.
    "infra-uat"          = { subject = "repo:${var.github_owner}/${var.infra_repo}:environment:infra-uat" }
    "infra-uat-destroy"  = { subject = "repo:${var.github_owner}/${var.infra_repo}:environment:infra-uat-destroy" }
    "infra-prod"         = { subject = "repo:${var.github_owner}/${var.infra_repo}:environment:infra-prod" }
    "infra-prod-destroy" = { subject = "repo:${var.github_owner}/${var.infra_repo}:environment:infra-prod-destroy" }
    # đẩy image: chỉ từ nhánh main của repo ứng dụng (subject theo ref, không có Environment)
    "acr-push" = { subject = "repo:${var.github_owner}/${var.app_repo}:ref:refs/heads/main" }
    # đẩy Helm chart: workflow release-chart ở repo templates, Environment release-chart chỉ nhận tag chart-v*
    "chart-push" = { subject = "repo:${var.github_owner}/${var.templates_repo}:environment:release-chart" }
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
