terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "azurerm" {
  features {}
  # The storage account has shared keys turned off: container operations use Entra ID.
  storage_use_azuread = true
  # The subscription comes from the environment variable ARM_SUBSCRIPTION_ID (never written into the code).
  subscription_id = var.subscription_id
}
