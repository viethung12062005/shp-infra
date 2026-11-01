# Azure Service Bus: một topic `shp-events`, mỗi consumer một subscription có bộ lọc, dead-letter sau 5 lần giao
# (13-events.md). Chỉ xác thực Entra ID (tắt SAS key), thứ tự theo subject bằng session.
locals {
  premium = var.sku == "Premium"
  # Mỗi consumer chỉ nhận đúng các loại event của mình.
  filters = { for name, types in var.subscriptions : name => "type IN (${join(", ", [for t in types : "'${t}'"])})" }
}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_servicebus_namespace" "this" {
  name                = "sb-${var.name_prefix}-${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  capacity            = local.premium ? 1 : 0
  tags                = var.tags

  premium_messaging_partitions  = local.premium ? 1 : 0
  local_auth_enabled            = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = !local.premium
}

resource "azurerm_servicebus_topic" "events" {
  name         = var.topic_name
  namespace_id = azurerm_servicebus_namespace.this.id

  requires_duplicate_detection            = true
  duplicate_detection_history_time_window = "PT10M"
  default_message_ttl                     = "P14D"
  support_ordering                        = true
}

resource "azurerm_servicebus_subscription" "consumer" {
  for_each = var.subscriptions

  name     = each.key
  topic_id = azurerm_servicebus_topic.events.id

  max_delivery_count                        = 5
  lock_duration                             = "PT1M"
  default_message_ttl                       = "P14D"
  requires_session                          = true
  dead_lettering_on_message_expiration      = true
  dead_lettering_on_filter_evaluation_error = true
}

# Subscription mới luôn có luật mặc định `$Default` (nhận tất cả). Provider không cho tạo/sửa luật trùng tên đó, nên ghi đè
# nó bằng ARM (PUT là upsert) để mỗi consumer chỉ nhận đúng loại event của mình, không rò event của service khác.
resource "azurerm_resource_group_template_deployment" "filters" {
  name                = "sb-filters-${azurerm_servicebus_namespace.this.name}"
  resource_group_name = var.resource_group_name
  deployment_mode     = "Incremental"

  template_content = jsonencode({
    "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    resources = [for name, filter in local.filters : {
      type       = "Microsoft.ServiceBus/namespaces/topics/subscriptions/rules"
      apiVersion = "2022-10-01-preview"
      name       = "${azurerm_servicebus_namespace.this.name}/${azurerm_servicebus_topic.events.name}/${name}/$Default"
      properties = { filterType = "SqlFilter", sqlFilter = { sqlExpression = filter } }
    }]
  })

  depends_on = [azurerm_servicebus_subscription.consumer]
}

module "private_endpoint" {
  count = local.premium ? 1 : 0

  source              = "../private-endpoint"
  name                = "pe-${azurerm_servicebus_namespace.this.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  subnet_id           = var.private_endpoints_subnet_id
  target_resource_id  = azurerm_servicebus_namespace.this.id
  subresource         = "namespace"
  private_dns_zone_id = var.private_dns_zone_id
}

resource "azurerm_role_assignment" "sender" {
  for_each = var.sender_principal_ids

  scope                = azurerm_servicebus_topic.events.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "receiver" {
  for_each = var.receiver_principal_ids

  scope                = azurerm_servicebus_subscription.consumer[each.key].id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = each.value
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "to-log-analytics"
  target_resource_id         = azurerm_servicebus_namespace.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# OBS-03: cảnh báo ngay khi có message nằm trong dead-letter queue.
resource "azurerm_monitor_metric_alert" "dead_letter" {
  count = var.action_group_id == null ? 0 : 1

  name                = "alert-${azurerm_servicebus_namespace.this.name}-dlq"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_servicebus_namespace.this.id]
  description         = "Có message trong dead-letter queue của Service Bus."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.ServiceBus/namespaces"
    metric_name      = "DeadletteredMessages"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = var.action_group_id
  }
}
