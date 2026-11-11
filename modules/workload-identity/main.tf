# One managed identity per service, linked to the ServiceAccount of the same name in the application namespace by a federated credential.
# Pods sign in to the data services with the ServiceAccount token: there is no password or key to leak.
# On the GitOps side: the service values set `serviceAccount.name: <service>` and `workloadIdentity: { enabled: true, clientId: <client_id> }`.
resource "azurerm_user_assigned_identity" "this" {
  for_each = toset(var.services)

  name                = "id-${var.name_prefix}-${each.value}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "this" {
  for_each = azurerm_user_assigned_identity.this

  name                = "aks-${each.key}"
  resource_group_name = var.resource_group_name
  parent_id           = each.value.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.oidc_issuer_url
  subject             = "system:serviceaccount:${var.namespace}:${each.key}"
}
