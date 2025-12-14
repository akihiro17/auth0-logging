provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  tenant_id           = var.tenant_id
  subscription_id     = var.subscription_id
  storage_use_azuread = true
}

provider "azuread" {
  tenant_id = var.tenant_id
}

provider "azapi" {
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}

provider "auth0" {
  domain = var.auth0_domain
}
