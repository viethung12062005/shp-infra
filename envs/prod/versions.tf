terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }

  # The backend configuration is passed at init (-backend-config=...), never hard-coded.
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    resource_group {
      # Allows destroying the environment while service-created resources remain (for example NetworkWatcher)
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
  storage_use_azuread = true
  subscription_id     = var.subscription_id
}
