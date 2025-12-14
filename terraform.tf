terraform {
  required_version = "~> 1.14.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.47.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "=3.5.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "=2.7.0"
    }
    auth0 = {
      source  = "auth0/auth0"
      version = "=1.36.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
}
