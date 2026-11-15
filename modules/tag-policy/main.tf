# Enforces the required tags at the environment's resource group scope with two built-in Azure Policies (both deny):
#   - "Require a tag on resources" (Indexed): denies creating/updating a taggable resource without the tag.
#   - "Require a tag on resource groups" (All): denies removing the tag from the resource group itself.
# The assignment resource itself cannot be tagged through the AzureRM provider, so the resources policy excludes
# Microsoft.Authorization/policyAssignments to avoid denying its own creation.

locals {
  require_tag_on_resources_id       = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
  require_tag_on_resource_groups_id = "/providers/Microsoft.Authorization/policyDefinitions/96670d01-0a4d-4649-9c89-2d3abc0a5025"
}

resource "azurerm_resource_group_policy_assignment" "require_tag_on_resources" {
  for_each = toset(var.required_tags)

  name                 = "require-tag-${each.value}"
  display_name         = "Require the '${each.value}' tag on resources"
  description          = "Denies creating or updating a resource in the environment without the '${each.value}' tag."
  resource_group_id    = var.resource_group_id
  policy_definition_id = local.require_tag_on_resources_id
  enforce              = true

  parameters = jsonencode({
    tagName = { value = each.value }
  })

  resource_selectors {
    name = "exclude-policy-assignments"
    selectors {
      kind   = "resourceType"
      not_in = ["Microsoft.Authorization/policyAssignments"]
    }
  }
}

resource "azurerm_resource_group_policy_assignment" "require_tag_on_resource_group" {
  for_each = toset(var.required_tags)

  name                 = "require-tag-rg-${each.value}"
  display_name         = "Require the '${each.value}' tag on the resource group"
  description          = "Denies removing the '${each.value}' tag from the environment resource group."
  resource_group_id    = var.resource_group_id
  policy_definition_id = local.require_tag_on_resource_groups_id
  enforce              = true

  parameters = jsonencode({
    tagName = { value = each.value }
  })
}
