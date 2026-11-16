output "id" { value = azurerm_servicebus_namespace.this.id }
output "name" { value = azurerm_servicebus_namespace.this.name }
output "endpoint" { value = azurerm_servicebus_namespace.this.endpoint }
output "topic_id" { value = azurerm_servicebus_topic.events.id }
output "queue_ids" {
  description = "queue name -> resource id."
  value       = { for name, queue in azurerm_servicebus_queue.this : name => queue.id }
}
output "queue_names" {
  description = "queue name -> namespace-qualified queue name."
  value       = { for name, queue in azurerm_servicebus_queue.this : name => queue.name }
}
