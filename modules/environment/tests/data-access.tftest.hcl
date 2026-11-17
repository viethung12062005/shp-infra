# Offline check for IAC-20 ("each service has access only to its own data store").
# Runs a real `terraform plan` of the whole environment module against mocked providers, so it needs no Azure
# credentials and creates nothing. It proves that the module plans and that the access derived from the role
# assignments and database users matches the table in the README. It does not prove what Azure would accept.
mock_provider "azurerm" {}
mock_provider "random" {}
mock_provider "kubernetes" {}

# The AKS provider mock cannot return the kubelet identity block that module.aks outputs, so the module is replaced by
# fixed outputs. Everything that consumes the cluster (federated credentials, Key Vault, observability) still plans.
override_module {
  target = module.aks
  outputs = {
    name                = "aks-mock"
    id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock/providers/Microsoft.ContainerService/managedClusters/aks-mock"
    oidc_issuer_url     = "https://oidc.example.invalid/00000000-0000-0000-0000-000000000000/"
    kubelet_object_id   = "00000000-0000-0000-0000-000000000003"
    ai_pool_name        = "ai"
    ai_pool_vm_size     = "Standard_D4s_v5"
    ai_pool_node_labels = { workload = "ai" }
    ai_pool_node_taints = ["workload=ai:NoSchedule"]
  }
}

variables {
  environment          = "uat"
  location             = "southeastasia"
  tenant_id            = "00000000-0000-0000-0000-000000000000"
  acr_id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shp-shared/providers/Microsoft.ContainerRegistry/registries/acrtest"
  address_space        = "10.60.0.0/16"
  created_at           = "2026-01-01"
  authorized_ip_ranges = ["203.0.113.5/32"]
  entra_admin = {
    object_id = "00000000-0000-0000-0000-000000000001"
    name      = "id-shp-infra-uat"
    type      = "ServicePrincipal"
  }
}

run "uat_plans_and_isolates_data_stores" {
  command = plan

  # Mongo: each service owns only its own database; services without Mongo have none.
  assert {
    condition     = alltrue([for svc, a in output.data_access : a.mongo_databases == [] || a.mongo_databases == [svc]])
    error_message = "A service may only have readWrite on a Mongo database named after itself."
  }
  assert {
    condition     = output.data_access["gateway"].mongo_databases == [] && output.data_access["scheduling"].mongo_databases == [] && output.data_access["audit"].mongo_databases == []
    error_message = "gateway, scheduling and audit must have no Mongo access."
  }
  # PostgreSQL (scheduling database) belongs to scheduling only.
  assert {
    condition     = [for svc, a in output.data_access : svc if length(a.postgres_databases) > 0] == ["scheduling"]
    error_message = "Only scheduling may use the scheduling PostgreSQL database."
  }
  # Redis: gateway and scheduling only.
  assert {
    condition     = join(",", sort([for svc, a in output.data_access : svc if a.redis])) == "gateway,scheduling"
    error_message = "Only gateway and scheduling may use Redis."
  }
  # Blob containers, search and Key Vault: one owner each.
  assert {
    condition     = [for svc, a in output.data_access : svc if a.blob_documents] == ["document"] && [for svc, a in output.data_access : svc if a.blob_audit] == ["audit"] && [for svc, a in output.data_access : svc if a.blob_mlops] == ["ml"] && [for svc, a in output.data_access : svc if a.blob_kb] == ["ai"]
    error_message = "Each blob container group must have exactly one owner service."
  }
  assert {
    condition     = [for svc, a in output.data_access : svc if a.search] == ["ai"] && [for svc, a in output.data_access : svc if a.key_vault_secrets] == ["ai"]
    error_message = "Only ai may use AI Search and read Key Vault secrets through the ai identity."
  }
  # The Keycloak identity is not one of the application services and has no application data store.
  assert {
    condition     = !contains(keys(output.data_access), "keycloak") && output.keycloak_values.database.name == "keycloak"
    error_message = "Keycloak must stay outside the service data-access table and use its own database."
  }
}

run "prod_sizing_plans" {
  command = plan

  variables {
    environment   = "prod"
    sizing        = "prod"
    address_space = "10.70.0.0/16"
  }

  assert {
    condition     = output.keycloak_values.database.auth == "password" && length(output.keycloak_values.keyVault.secretKeys) == 2
    error_message = "Keycloak keeps its two secrets in Key Vault in password mode."
  }
}
