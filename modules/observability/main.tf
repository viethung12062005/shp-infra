# Monitoring: Azure Managed Prometheus receives metrics from AKS, Azure Managed Grafana serves the dashboards (NFR-OBS, tasks OBS-01..03).
# Logs and traces live in Log Analytics / Application Insights (monitoring module). No patient data in metrics:
# Prometheus only collects infrastructure and application metrics (latency, errors, counts); labels carry no patient identifier.

# ---- Managed Prometheus: collects metrics from the cluster into the Azure Monitor workspace
resource "azurerm_monitor_data_collection_endpoint" "prometheus" {
  name                          = "dce-${var.name_prefix}-prom"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  kind                          = "Linux"
  public_network_access_enabled = true # the agent in AKS sends over the Azure network; authenticated with the cluster identity
  tags                          = var.tags
}

resource "azurerm_monitor_data_collection_rule" "prometheus" {
  name                        = "dcr-${var.name_prefix}-prom"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  kind                        = "Linux"
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prometheus.id
  tags                        = var.tags

  data_sources {
    prometheus_forwarder {
      name    = "PrometheusDataSource"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }

  destinations {
    monitor_account {
      monitor_account_id = var.monitor_workspace_id
      name               = "MonitoringAccount1"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }
}

resource "azurerm_monitor_data_collection_rule_association" "prometheus" {
  name                    = "dcra-${var.name_prefix}-prom"
  target_resource_id      = var.aks_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prometheus.id
}

# The name "configurationAccessEndpoint" is mandatory: the agent fetches its scrape configuration through this endpoint
resource "azurerm_monitor_data_collection_rule_association" "prometheus_endpoint" {
  name                        = "configurationAccessEndpoint"
  target_resource_id          = var.aks_id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prometheus.id
}

# ---- Infrastructure alerts (PromQL). The action group is optional; without one the alerts still show in Azure Monitor.
locals {
  rule_actions = var.action_group_id == null ? [] : [var.action_group_id]
}

resource "azurerm_monitor_alert_prometheus_rule_group" "platform" {
  name                = "prg-${var.name_prefix}-platform"
  resource_group_name = var.resource_group_name
  location            = var.location
  cluster_name        = var.aks_name
  interval            = "PT1M"
  scopes              = [var.monitor_workspace_id, var.aks_id]
  tags                = var.tags

  rule {
    alert      = "PodCrashLooping"
    expression = "max_over_time(kube_pod_container_status_waiting_reason{reason=\"CrashLoopBackOff\", namespace=\"${var.apps_namespace}\"}[5m]) >= 1"
    for        = "PT5M"
    severity   = 2
    labels     = { team = "platform" }
    annotations = {
      summary = "A pod in ${var.apps_namespace} keeps restarting (CrashLoopBackOff)."
    }

    dynamic "action" {
      for_each = local.rule_actions
      content {
        action_group_id = action.value
      }
    }
  }

  rule {
    alert      = "DeploymentReplicasUnavailable"
    expression = "kube_deployment_status_replicas_available{namespace=\"${var.apps_namespace}\"} < kube_deployment_spec_replicas{namespace=\"${var.apps_namespace}\"}"
    for        = "PT10M"
    severity   = 2
    labels     = { team = "platform" }
    annotations = {
      summary = "A Deployment has been short of ready replicas for more than 10 minutes."
    }

    dynamic "action" {
      for_each = local.rule_actions
      content {
        action_group_id = action.value
      }
    }
  }

  rule {
    alert      = "ContainerMemoryNearLimit"
    expression = "(container_memory_working_set_bytes{namespace=\"${var.apps_namespace}\", container!=\"\"} / on(namespace, pod, container) kube_pod_container_resource_limits{resource=\"memory\", namespace=\"${var.apps_namespace}\"}) > 0.9"
    for        = "PT10M"
    severity   = 3
    labels     = { team = "platform" }
    annotations = {
      summary = "A container uses more than 90% of its memory limit: risk of OOMKilled."
    }

    dynamic "action" {
      for_each = local.rule_actions
      content {
        action_group_id = action.value
      }
    }
  }

  rule {
    alert      = "NodeNotReady"
    expression = "kube_node_status_condition{condition=\"Ready\", status=\"true\"} == 0"
    for        = "PT5M"
    severity   = 1
    labels     = { team = "platform" }
    annotations = {
      summary = "A node has not been Ready for more than 5 minutes."
    }

    dynamic "action" {
      for_each = local.rule_actions
      content {
        action_group_id = action.value
      }
    }
  }
}

# ---- Managed Grafana: sign-in with Entra ID; reads Prometheus metrics and Azure Monitor logs with its own identity
resource "azurerm_dashboard_grafana" "this" {
  name                  = substr("graf-${var.name_prefix}", 0, 23)
  resource_group_name   = var.resource_group_name
  location              = var.location
  grafana_major_version = var.grafana_major_version
  sku                   = "Standard"
  tags                  = var.tags

  api_key_enabled                   = false # no API keys are issued; integrations use Entra identities
  deterministic_outbound_ip_enabled = false
  public_network_access_enabled     = var.grafana_public_network_access
  zone_redundancy_enabled           = false

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = var.monitor_workspace_id
  }
}

resource "azurerm_role_assignment" "grafana_prometheus" {
  scope                = var.monitor_workspace_id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "grafana_monitor" {
  scope                = var.resource_group_id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "grafana_logs" {
  scope                = var.log_analytics_workspace_id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_dashboard_grafana.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "grafana_admin" {
  for_each = var.grafana_admin_principal_ids

  scope                = azurerm_dashboard_grafana.this.id
  role_definition_name = "Grafana Admin"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "grafana_viewer" {
  for_each = var.grafana_viewer_principal_ids

  scope                = azurerm_dashboard_grafana.this.id
  role_definition_name = "Grafana Viewer"
  principal_id         = each.value
}
