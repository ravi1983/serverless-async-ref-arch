resource "azurerm_service_plan" "func_plan" {
  name = "plan-docs-processing"
  resource_group_name = azurerm_resource_group.serverless_rg.name
  location = var.REGION

  os_type = "Linux"
  sku_name = "FC1"
}

resource "azurerm_storage_container" "func_releases" {
  name = "function-releases"
  storage_account_id = azurerm_storage_account.source_storage.id
  container_access_type = "private"
}

resource "azurerm_function_app_flex_consumption" "parser_func" {
  name = "func-parser-2026"
  location = var.REGION
  resource_group_name = azurerm_resource_group.serverless_rg.name
  service_plan_id = azurerm_service_plan.func_plan.id

  # Storage Configuration for Flex
  storage_container_type = "blobContainer"
  storage_container_endpoint = "${azurerm_storage_account.source_storage.primary_blob_endpoint}${azurerm_storage_container.func_releases.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key = azurerm_storage_account.source_storage.primary_access_key

  # Runtime and Scale Configuration
  runtime_name = "python"
  runtime_version = "3.12"
  maximum_instance_count = 40
  instance_memory_in_mb = 2048

  site_config {
    cors {
      allowed_origins = ["https://portal.azure.com"]
      support_credentials = true
    }
  }

  app_settings = {
    AZURE_OPENAI_ENDPOINT = azurerm_cognitive_account.openai.endpoint
    AZURE_OPENAI_KEY = azurerm_cognitive_account.openai.primary_access_key
    TARGET_STORAGE_CONNECTION = azurerm_storage_account.target_storage.primary_connection_string
    TARGET_CONTAINER = azurerm_storage_container.target_container.name
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "func_openai_access" {
  scope                = azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_function_app_flex_consumption.parser_func.identity[0].principal_id
}

# resource "azurerm_managed_api_connection" "azureblob" {
#   name                = "azureblob" # This must match your JSON path exactly
#   resource_group_name = azurerm_resource_group.serverless_rg.name
#   location            = azurerm_resource_group.serverless_rg.location
#   managed_api_id      = "/subscriptions/${var.SUBSCRIPTION}/providers/Microsoft.Web/locations/${azurerm_resource_group.serverless_rg.location}/managedApis/azureblob"
# }

resource "azurerm_logic_app_workflow" "doc_processor" {
  name                = "wf-doc-processor-2026"
  location            = azurerm_resource_group.serverless_rg.location
  resource_group_name = azurerm_resource_group.serverless_rg.name

  identity {
    type = "SystemAssigned"
  }
}

resource "azapi_update_resource" "logic_app_definition" {
  type        = "Microsoft.Logic/workflows@2019-05-01"
  resource_id = azurerm_logic_app_workflow.doc_processor.id

  body = {
    properties = jsondecode(templatefile("${path.module}/logic-app/workflow.json", {
      sub_id = var.SUBSCRIPTION
      rg = azurerm_resource_group.serverless_rg.name,
      email = var.USER_EMAIL
      location = azurerm_resource_group.serverless_rg.location
    }))
  }
}


resource "azurerm_role_assignment" "logic_app_storage_read" {
  scope                = azurerm_storage_account.source_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_logic_app_workflow.doc_processor.identity[0].principal_id
}

resource "azurerm_role_assignment" "logic_app_ocr_access" {
  scope                = azurerm_cognitive_account.ocr_image_service.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_logic_app_workflow.doc_processor.identity[0].principal_id
}

resource "azurerm_role_assignment" "logic_app_to_func" {
  scope                = azurerm_function_app_flex_consumption.parser_func.id
  role_definition_name = "Website Contributor"
  principal_id         = azurerm_logic_app_workflow.doc_processor.identity[0].principal_id
}

resource "azurerm_role_assignment" "logic_app_storage_write" {
  scope                = azurerm_storage_account.target_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_logic_app_workflow.doc_processor.identity[0].principal_id
}
