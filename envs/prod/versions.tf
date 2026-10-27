terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }

  # Cấu hình backend truyền lúc init (-backend-config=...), không ghi cứng vào code.
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    resource_group {
      # Cho phép hủy môi trường khi còn tài nguyên do dịch vụ tự tạo (ví dụ NetworkWatcher)
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
  storage_use_azuread = true
  subscription_id     = var.subscription_id
}
