resource "auth0_log_stream" "example" {
  name   = "Azure logs"
  type   = "eventgrid"
  status = "active"

  sink {
    azure_region          = local.location
    azure_resource_group  = azurerm_resource_group.example.name
    azure_subscription_id = local.subscription_id
  }

  depends_on = [azurerm_eventgrid_partner_configuration.example]
}

resource "azurerm_eventgrid_partner_configuration" "example" {
  resource_group_name                     = azurerm_resource_group.example.name
  default_maximum_expiration_time_in_days = 7

  partner_authorization {
    # ref. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/eventgrid_partner_configuration
    partner_registration_id = "804a11ca-ce9b-4158-8e94-3c8dc7a072ec"
    partner_name            = "Auth0"
  }
}
