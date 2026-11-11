# Azure AI Search for the RAG knowledge base of the ai service (06-data-ai.md, index kb-chunks-v1). Entra ID only (API keys off),
# reachable only through the private endpoint (needs SKU Basic or higher).
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_search_service" "this" {
  name                = "srch-${var.name_prefix}-${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  replica_count       = var.replica_count
  partition_count     = 1
  tags                = var.tags

  local_authentication_enabled  = false
  public_network_access_enabled = false
  semantic_search_sku           = var.semantic_search_sku
}

module "private_endpoint" {
  source              = "../private-endpoint"
  name                = "pe-${azurerm_search_service.this.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  subnet_id           = var.private_endpoints_subnet_id
  target_resource_id  = azurerm_search_service.this.id
  subresource         = "searchService"
  private_dns_zone_id = var.private_dns_zone_id
}

# The ai service reads/writes documents in the index; creating/changing the index (schema) belongs to the deployment job, which needs the service management role.
resource "azurerm_role_assignment" "index_data" {
  for_each = var.index_contributor_principal_ids

  scope                = azurerm_search_service.this.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "service" {
  for_each = var.service_contributor_principal_ids

  scope                = azurerm_search_service.this.id
  role_definition_name = "Search Service Contributor"
  principal_id         = each.value
}
