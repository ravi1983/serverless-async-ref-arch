terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    azapi = {
      source = "Azure/azapi"
    }
  }
}

provider "azapi" {
  subscription_id = var.SUBSCRIPTION
}

provider "azurerm" {
  features {}
  subscription_id = var.SUBSCRIPTION
  resource_provider_registrations = "core"
}
