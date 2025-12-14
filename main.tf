locals {
  resource_group_name = "example"
  location            = "japaneast"
}

variable "tenant_id" {
  description = "The Azure tenant ID."
  type        = string
  sensitive   = true
}

variable "subscription_id" {
  description = "The Azure subscription ID."
  type        = string
  sensitive   = true
}

variable "auth0_domain" {
  description = "The Auth0 domain for the log stream."
  type        = string
  sensitive   = true
}

resource "azurerm_resource_group" "example" {
  location = local.location
  name     = local.resource_group_name
}

resource "azurerm_storage_account" "log" {
  name                     = "exampleforlogarchive"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false

  public_network_access_enabled = true
}

resource "azurerm_storage_account" "example" {
  name                     = "exampleauthlogstream"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false

  public_network_access_enabled = true
}

resource "azurerm_storage_container" "example" {
  name                  = "example-container"
  storage_account_id    = azurerm_storage_account.example.id
  container_access_type = "private"
}

resource "azurerm_service_plan" "example" {
  name                = "example-app-service-plan"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  os_type             = "Linux"
  sku_name            = "FC1" # Flex Consumption SKU
}

resource "azurerm_application_insights" "example" {
  name                = "example-appinsights"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  application_type    = "Node.JS"
}

resource "azurerm_function_app_flex_consumption" "example" {
  name                = "auth0-logging-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  service_plan_id     = azurerm_service_plan.example.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.example.primary_blob_endpoint}${azurerm_storage_container.example.name}"
  storage_authentication_type = "SystemAssignedIdentity"
  runtime_name                = "node"
  runtime_version             = "20"
  maximum_instance_count      = 40
  instance_memory_in_mb       = 2048

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.example.connection_string
  }

  app_settings = {
    # workaround for the azure terraform provider issue
    # ref. https://github.com/hashicorp/terraform-provider-azurerm/issues/30732#issuecomment-3360715578
    "AzureWebJobsStorage" = ""

    "AzureWebJobsStorage__accountName"    = azurerm_storage_account.log.name
    "AzureWebJobsStorage__blobServiceUri" = azurerm_storage_account.log.primary_blob_endpoint
    "AzureWebJobsStorage__credential"     = "managedidentity"
  }

  # `az functionapp deployment` mutates these values after deploy; ignore them to keep plans clean.
  lifecycle {
    ignore_changes = [
      tags["hidden-link: /app-insights-resource-id"],
    ]
  }

  # `zip_deploy_file` does not work with Flex Consumption plan
  # ref. https://learn.microsoft.com/en-us/azure/azure-functions/functions-deployment-technologies?tabs=linux#deployment-technology-availability
  # ref. https://github.com/hashicorp/terraform-provider-azurerm/issues/29630
  # zip_deploy_file = data.archive_file.function_zip.output_path
}

resource "azurerm_role_assignment" "storage_for_function" {
  role_definition_name = "Storage Blob Data Owner"
  scope                = azurerm_storage_account.example.id
  principal_id         = azurerm_function_app_flex_consumption.example.identity[0].principal_id
}

resource "azurerm_role_assignment" "log_storage_for_function" {
  role_definition_name = "Storage Blob Data Owner"
  scope                = azurerm_storage_account.log.id
  principal_id         = azurerm_function_app_flex_consumption.example.identity[0].principal_id
}

resource "azurerm_role_assignment" "current_user_log_storage" {
  role_definition_name = "Storage Blob Data Owner"
  scope                = azurerm_storage_account.log.id
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "auth0_log_stream" "example" {
  name   = "Azure logs"
  type   = "eventgrid"
  status = "active"

  sink {
    azure_region          = local.location
    azure_resource_group  = azurerm_resource_group.example.name
    azure_subscription_id = var.subscription_id
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

data "azapi_resource" "partner_topic" {
  type      = "Microsoft.EventGrid/partnerTopics@2022-06-15"
  name      = auth0_log_stream.example.sink[0].azure_partner_topic
  parent_id = azurerm_resource_group.example.id
}

resource "azapi_resource_action" "activate_partner_topic" {
  type        = "Microsoft.EventGrid/partnerTopics@2022-06-15"
  resource_id = data.azapi_resource.partner_topic.id
  action      = "activate"
  method      = "POST"

  body = {}
}


resource "azapi_resource" "event_subscription" {
  type      = "Microsoft.EventGrid/partnerTopics/eventSubscriptions@2022-06-15"
  name      = "example-event-subscription"
  parent_id = data.azapi_resource.partner_topic.id

  body = {
    properties = {
      destination = {
        endpointType = "AzureFunction"
        properties = {
          resourceId = "${azurerm_function_app_flex_consumption.example.id}/functions/${azurerm_function_app_flex_consumption.example.name}"
        }
      }
      eventDeliverySchema = "CloudEventSchemaV1_0"
    }
  }

  depends_on = [
    azapi_resource_action.activate_partner_topic,
    azurerm_function_app_flex_consumption.example,
    terraform_data.deploy_functions,
  ]
}

data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "./auth0Logging"
  output_path = "${path.module}/.tmp/function.zip"

  excludes = [
    "local.settings.json",
    "node_modules/**",
    ".npm/**",
  ]
}

resource "terraform_data" "deploy_functions" {
  triggers_replace = {
    zip_file_path = data.archive_file.function_zip.output_md5
  }

  provisioner "local-exec" {
    command = <<-EOT
    az functionapp deployment source config-zip \
    --src ${data.archive_file.function_zip.output_path} \
    --resource-group ${local.resource_group_name} \
    --name ${azurerm_function_app_flex_consumption.example.name} \
    --timeout 180 \
    --build-remote true
    EOT
  }

  depends_on = [
    azurerm_role_assignment.storage_for_function,
    azurerm_role_assignment.log_storage_for_function,
    azurerm_role_assignment.current_user_storage,
    azurerm_role_assignment.current_user_log_storage,
  ]
}

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "current_user_storage" {
  role_definition_name = "Storage Blob Data Owner"
  scope                = azurerm_storage_account.example.id
  principal_id         = data.azurerm_client_config.current.object_id
}
