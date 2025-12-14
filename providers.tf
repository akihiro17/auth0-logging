provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  tenant_id           = local.tenant_id
  subscription_id     = local.subscription_id
  storage_use_azuread = true
}

provider "azuread" {
  tenant_id = local.tenant_id
}

provider "azapi" {
  tenant_id       = local.tenant_id
  subscription_id = local.subscription_id
}

provider "auth0" {
  domain = local.auth0_domain
}
