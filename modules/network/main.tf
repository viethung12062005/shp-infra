locals {
  # The /16 is split into: AKS nodes (/20), private endpoints (/24), delegated PostgreSQL (/24)
  subnets = {
    aks               = cidrsubnet(var.address_space, 4, 0)
    private-endpoints = cidrsubnet(var.address_space, 8, 16)
    postgres          = cidrsubnet(var.address_space, 8, 17)
  }
}

# A subscription policy can deny a subnet that is created without a network security group, and azurerm_subnet cannot
# set one at creation. So the subnets are declared inline in the virtual network, each with its own NSG (default rules).
resource "azurerm_network_security_group" "subnet" {
  for_each            = local.subnets
  name                = "nsg-${var.name_prefix}-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.address_space]
  tags                = var.tags

  subnet {
    name             = "snet-aks"
    address_prefixes = [local.subnets.aks]
    security_group   = azurerm_network_security_group.subnet["aks"].id
  }

  subnet {
    name                              = "snet-private-endpoints"
    address_prefixes                  = [local.subnets.private-endpoints]
    security_group                    = azurerm_network_security_group.subnet["private-endpoints"].id
    private_endpoint_network_policies = "Enabled"
  }

  subnet {
    name             = "snet-postgres"
    address_prefixes = [local.subnets.postgres]
    security_group   = azurerm_network_security_group.subnet["postgres"].id

    delegation {
      name = "postgres-flexible"
      service_delegation {
        name    = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }
}

locals {
  subnet_ids = { for s in azurerm_virtual_network.this.subnet : s.name => s.id }
}

resource "azurerm_private_dns_zone" "this" {
  for_each            = toset(var.private_dns_zones)
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = coalesce(var.private_dns_zone_tags, var.tags)
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = azurerm_private_dns_zone.this
  name                  = "link-${var.name_prefix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.this.id
  tags                  = coalesce(var.private_dns_zone_tags, var.tags)
}
