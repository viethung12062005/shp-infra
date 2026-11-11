# Least-privilege role assignments for the 6 GitHub identities (IAC-03). Kept separate so an environment that blocks
# Microsoft.Authorization/*/Write can still create the infrastructure; see var.create_role_assignments.

locals {
  subscription_scope = "/subscriptions/${var.subscription_id}"

  required_role_assignments = concat(
    [for k in ["acr-push", "chart-push"] : {
      identity = k
      role     = "AcrPush"
      scope    = azurerm_container_registry.acr.id
    }],
    [for k in ["ci-plan", "infra-uat", "infra-uat-destroy", "infra-prod", "infra-prod-destroy"] : {
      identity = k
      role     = "Storage Blob Data Contributor"
      scope    = azurerm_storage_account.tfstate.id
    }],
    [{
      identity = "ci-plan"
      role     = "Reader"
      scope    = local.subscription_scope
    }],
    [for k in ["infra-uat", "infra-uat-destroy", "infra-prod", "infra-prod-destroy"] : {
      identity = k
      role     = "Contributor"
      scope    = local.subscription_scope
    }],
    [for k in ["infra-uat", "infra-uat-destroy", "infra-prod", "infra-prod-destroy"] : {
      identity = k
      role     = "Role Based Access Control Administrator"
      scope    = local.subscription_scope
    }],
  )
}

resource "azurerm_role_assignment" "github" {
  for_each = var.create_role_assignments ? {
    for ra in local.required_role_assignments : "${ra.identity}:${ra.role}" => ra
  } : {}

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.github[each.value.identity].principal_id
}
