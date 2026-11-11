# ALWAYS-ON resources (cheap, no patient data): state, ACR, identities for GitHub OIDC, budget.
# Run ONCE by hand by the SA; then move the state into this same storage account (see README).

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

# The state container is created through the data plane (Entra), so it needs the "Storage Blob Data Contributor" role;
# an environment that blocks Microsoft.Authorization/*/Write (sandbox) cannot grant itself that role. Set
# manage_state_container=false and create the container with an account that has data access (see README).
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

# ---------- Identities for GitHub Actions (OIDC, no secret) ----------
locals {
  github_issuer = "https://token.actions.githubusercontent.com"
  identities = {
    # read access: the plan step of env-provision and cost-guard. Both run from the main branch, with no Environment
    # (CI on pull requests only runs static checks and never signs in to Azure).
    "ci-plan" = { subject = "repo:${var.github_owner}/${var.infra_repo}:ref:refs/heads/main" }
    # provision/destroy an environment: only when the job runs in the matching GitHub Environment. Each Environment is
    # limited to the main branch (deployment branch policy), so another branch cannot get a token with this subject.
    "infra-uat"          = { subject = "repo:${var.github_owner}/${var.infra_repo}:environment:infra-uat" }
    "infra-uat-destroy"  = { subject = "repo:${var.github_owner}/${var.infra_repo}:environment:infra-uat-destroy" }
    "infra-prod"         = { subject = "repo:${var.github_owner}/${var.infra_repo}:environment:infra-prod" }
    "infra-prod-destroy" = { subject = "repo:${var.github_owner}/${var.infra_repo}:environment:infra-prod-destroy" }
    # push images: only from the main branch of the application repo (subject by ref, no Environment)
    "acr-push" = { subject = "repo:${var.github_owner}/${var.app_repo}:ref:refs/heads/main" }
    # push the Helm chart: the release-chart workflow in the templates repo; Environment release-chart only accepts chart-v* tags
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

# ---------- Budget ----------
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
