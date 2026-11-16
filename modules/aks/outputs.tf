output "name" { value = azurerm_kubernetes_cluster.this.name }
output "id" { value = azurerm_kubernetes_cluster.this.id }
output "oidc_issuer_url" { value = azurerm_kubernetes_cluster.this.oidc_issuer_url }
output "kubelet_object_id" { value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id }

output "ai_pool_name" {
  value = var.enable_ai_pool ? azurerm_kubernetes_cluster_node_pool.ai[0].name : null
}

output "ai_pool_vm_size" {
  value = var.enable_ai_pool ? azurerm_kubernetes_cluster_node_pool.ai[0].vm_size : null
}

output "ai_pool_node_labels" {
  description = "Labels the ai-service/Ollama pods must select with nodeSelector."
  value       = var.enable_ai_pool ? azurerm_kubernetes_cluster_node_pool.ai[0].node_labels : {}
}

output "ai_pool_node_taints" {
  description = "Taints the ai-service/Ollama pods must tolerate."
  value       = var.enable_ai_pool ? azurerm_kubernetes_cluster_node_pool.ai[0].node_taints : []
}
