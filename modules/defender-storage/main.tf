# Microsoft Defender for Storage scans every new blob in the documents account and publishes
# Microsoft.Security.MalwareScanningResult events to an Event Grid custom topic. The topic subscription then
# routes each result to an Azure Service Bus queue that the document service consumes (05-storage-audit-blob §2).
#
# Event Grid *system topics* are not used here: Defender's `scanResultsEventGridTopicResourceId` setting accepts a
# Microsoft.EventGrid/topics resource only.
resource "azurerm_eventgrid_topic" "scan_results" {
  count = var.enabled ? 1 : 0

  name                = "egt-${var.name_prefix}-scans"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  local_auth_enabled = false
  # Defender for Storage cannot deliver to a topic that is reachable only through a private endpoint. The events carry
  # blob URIs and malware names, never clinical data; the topic stays keyless and Entra ID only.
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_security_center_storage_defender" "this" {
  count = var.enabled ? 1 : 0

  storage_account_id = var.storage_account_id

  override_subscription_settings_enabled      = true
  malware_scanning_on_upload_enabled          = true
  malware_scanning_on_upload_cap_gb_per_month = var.malware_scanning_on_upload_cap_gb_per_month
  scan_results_event_grid_topic_id            = azurerm_eventgrid_topic.scan_results[0].id
}

# The topic identity delivers with Entra ID, so the queue stays keyless (local_auth_enabled = false on the namespace).
resource "azurerm_role_assignment" "eventgrid_sender" {
  count = var.enabled && var.create_role_assignments ? 1 : 0

  scope                = var.servicebus_queue_id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_eventgrid_topic.scan_results[0].identity[0].principal_id
}

resource "azurerm_eventgrid_event_subscription" "scan_results" {
  count = var.enabled ? 1 : 0

  name  = "scan-results-to-document"
  scope = azurerm_eventgrid_topic.scan_results[0].id

  included_event_types          = ["Microsoft.Security.MalwareScanningResult"]
  event_delivery_schema         = "EventGridSchema"
  service_bus_queue_endpoint_id = var.servicebus_queue_id

  delivery_identity {
    type = "SystemAssigned"
  }

  retry_policy {
    max_delivery_attempts = 30
    event_time_to_live    = 1440 # minutes (24 hours), the provider's number type
  }

  # The sender role must exist before Event Grid validates and delivers the first event.
  depends_on = [azurerm_role_assignment.eventgrid_sender]
}

# Delivery and publish failures are visible in Log Analytics next to the blob access logs.
resource "azurerm_monitor_diagnostic_setting" "scan_results" {
  count = var.enabled ? 1 : 0

  name                       = "to-log-analytics"
  target_resource_id         = azurerm_eventgrid_topic.scan_results[0].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "DeliveryFailures"
  }

  enabled_log {
    category = "PublishFailures"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
