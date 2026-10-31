# Mỗi service một managed identity, liên kết với ServiceAccount cùng tên trong namespace ứng dụng bằng federated credential.
# Pod đăng nhập các dịch vụ dữ liệu bằng token của ServiceAccount: không có mật khẩu hay khóa nào để lộ.
# Phía GitOps: values của service đặt `serviceAccount.name: <service>` và `workloadIdentity: { enabled: true, clientId: <client_id> }`.
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
