resource "azurerm_resource_group" "serverless_rg" {
  name = "serverless_rg"
  location = var.REGION

  tags = {
    environment = var.ENV
  }
}

resource "azurerm_storage_account" "source_storage" {
  name = "srcdocs2026"
  resource_group_name = azurerm_resource_group.serverless_rg.name
  location = azurerm_resource_group.serverless_rg.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "source_container" {
  name = "uploads"
  storage_account_id = azurerm_storage_account.source_storage.id
  container_access_type = "private"
}

resource "azurerm_storage_account" "target_storage" {
  name = "destresults2026"
  resource_group_name = azurerm_resource_group.serverless_rg.name
  location = azurerm_resource_group.serverless_rg.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "target_container" {
  name = "results"
  storage_account_id = azurerm_storage_account.target_storage.id
  container_access_type = "private"
}

resource "azurerm_cognitive_account" "ocr_image_service" {
  name = "ocr-image-service-2026-v1"
  location = azurerm_resource_group.serverless_rg.location
  resource_group_name = azurerm_resource_group.serverless_rg.name

  kind = "FormRecognizer"
  sku_name = "S0"

  # This is needed for Logic function to hit this endpoint
  custom_subdomain_name = "ocr-image-service-2026-v1"
}

resource "azurerm_cognitive_account" "openai" {
  name = "aoai-docs-2026"
  location = azurerm_resource_group.serverless_rg.location
  resource_group_name = azurerm_resource_group.serverless_rg.name
  kind = "OpenAI"
  sku_name = "S0"
}

resource "azurerm_cognitive_deployment" "gpt4_1_mini" {
  name = "gpt-4.1-mini"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format = "OpenAI"
    name = "gpt-4.1-mini"
    version = "2025-04-14"
  }

  sku {
    name = "GlobalStandard"
    capacity = 10
  }
}

resource "azapi_resource" "email_service" {
  type      = "Microsoft.Communication/emailServices@2023-03-31"
  name      = "email-docs-2026"
  location  = "Global"
  parent_id = azurerm_resource_group.serverless_rg.id
  body      = { properties = { dataLocation = "United States" } }
}

resource "azapi_resource" "managed_domain" {
  type      = "Microsoft.Communication/emailServices/domains@2023-03-31"
  name      = "AzureManagedDomain"
  parent_id = azapi_resource.email_service.id
  location  = "Global"
  body      = { properties = { domainManagement = "AzureManaged" } }
}

resource "azurerm_communication_service" "acs" {
  name                = "acs-docs-2026"
  resource_group_name = azurerm_resource_group.serverless_rg.name
  data_location       = "United States"
}

resource "azurerm_communication_service_email_domain_association" "link" {
  communication_service_id = azurerm_communication_service.acs.id
  email_service_domain_id  = azapi_resource.managed_domain.id
}
