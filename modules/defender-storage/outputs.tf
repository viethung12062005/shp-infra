output "eventgrid_topic_id" {
  value = var.enabled ? azurerm_eventgrid_topic.scan_results[0].id : null
}

output "eventgrid_topic_name" {
  value = var.enabled ? azurerm_eventgrid_topic.scan_results[0].name : null
}

output "eventgrid_principal_id" {
  description = "System-assigned identity of the topic; it sends to the queue, so it needs Azure Service Bus Data Sender."
  value       = var.enabled ? azurerm_eventgrid_topic.scan_results[0].identity[0].principal_id : null
}

output "event_subscription_id" {
  value = var.enabled ? azurerm_eventgrid_event_subscription.scan_results[0].id : null
}

output "scan_results_event_type" {
  value = "Microsoft.Security.MalwareScanningResult"
}
