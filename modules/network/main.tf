resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.address_space]
  tags                = var.tags
}

locals {
  # /16 chia thành: nodes AKS (/20), private endpoint (/24), PostgreSQL delegated (/24)
  subnets = {
    aks               = cidrsubnet(var.address_space, 4, 0)
    private-endpoints = cidrsubnet(var.address_space, 8, 16)
    postgres          = cidrsubnet(var.address_space, 8, 17)
  }
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.subnets.aks]
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [local.subnets.private-endpoints]
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet" "postgres" {
  name                 = "snet-postgres"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [local.subnets.postgres]

  delegation {
    name = "postgres-flexible"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "this" {
  for_each            = toset(var.private_dns_zones)
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = azurerm_private_dns_zone.this
  name                  = "link-${var.name_prefix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.this.id
  tags                  = var.tags
}
