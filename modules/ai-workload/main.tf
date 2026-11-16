# One-time cluster objects for the ai workload. Application manifests stay in shp-gitops/Argo CD; only the storage
# claim and the Key Vault reference are provisioned here, and the module is opt-in because the Kubernetes provider
# needs a kubeconfig. Run it as a second apply after the cluster and its namespaces exist (ENV-01).
provider "kubernetes" {
  config_path = var.kubeconfig_path
}

# Ollama keeps bge-m3 and qwen2.5 in the cache, so a container restart does not download several gigabytes again.
resource "kubernetes_persistent_volume_claim" "ollama_models" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "ollama-models"
    namespace = var.ollama_namespace
    labels = {
      "app.kubernetes.io/name"    = "ollama"
      "app.kubernetes.io/part-of" = "shp"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name

    resources {
      requests = { storage = var.model_cache_size }
    }
  }

  # The Ollama deployment that Argo CD creates later mounts the claim; do not block this apply until then.
  wait_until_bound = false
}

# The Secrets Store CSI driver mounts the DeepSeek/Gemini keys from Key Vault with the ai workload identity. The
# values are created in Key Vault out of band and are never written to the repository or to Helm values.
resource "kubernetes_manifest" "ai_key_vault_secrets" {
  count = var.enabled ? 1 : 0

  manifest = {
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"
    metadata = {
      name      = var.secret_provider_class_name
      namespace = var.ai_namespace
      labels    = { "app.kubernetes.io/part-of" = "shp" }
    }
    spec = {
      provider = "azure"
      parameters = {
        usePodIdentity = "false"
        clientID       = var.ai_client_id
        keyvaultName   = var.key_vault_name
        tenantId       = var.tenant_id
        objects = yamlencode({
          array = [
            for name in var.key_vault_secret_names : {
              objectName = name
              objectType = "secret"
            }
          ]
        })
      }
    }
  }
}
