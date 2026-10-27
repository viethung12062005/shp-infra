terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "azurerm" {
  features {}
  # Storage account tắt shared key: thao tác container dùng Entra ID.
  storage_use_azuread = true
  # Subscription lấy từ biến môi trường ARM_SUBSCRIPTION_ID (không ghi vào code).
  subscription_id = var.subscription_id
}
