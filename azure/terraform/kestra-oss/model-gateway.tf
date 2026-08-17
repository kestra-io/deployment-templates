resource "azurerm_cognitive_account" "model" {
  count = var.enable_model_gateway ? 1 : 0

  name                          = "kestra-ai-${random_string.suffix.result}"
  location                      = var.model_gateway_location
  resource_group_name           = azurerm_resource_group.rg.name
  kind                          = "OpenAI"
  sku_name                      = "S0"
  custom_subdomain_name         = "kestra-ai-${random_string.suffix.result}"
  local_auth_enabled            = false
  public_network_access_enabled = true
}

resource "azurerm_cognitive_deployment" "model" {
  count = var.enable_model_gateway ? 1 : 0

  name                 = var.model_deployment_name
  cognitive_account_id = azurerm_cognitive_account.model[0].id

  model {
    format  = "OpenAI"
    name    = var.model_name
    version = var.model_version
  }

  sku {
    name     = var.model_sku_name
    capacity = var.model_capacity
  }
}

resource "azurerm_api_management" "model_gateway" {
  count = var.enable_model_gateway ? 1 : 0

  name                = "kestra-model-gw-${random_string.suffix.result}"
  location            = var.model_gateway_location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = var.model_gateway_publisher_name
  publisher_email     = var.model_gateway_publisher_email
  sku_name            = var.model_gateway_sku_name

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "model_gateway" {
  count = var.enable_model_gateway ? 1 : 0

  scope                = azurerm_cognitive_account.model[0].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_api_management.model_gateway[0].identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_api_management_api" "model_gateway" {
  count = var.enable_model_gateway ? 1 : 0

  name                  = "kestra-model-gateway"
  resource_group_name   = azurerm_resource_group.rg.name
  api_management_name   = azurerm_api_management.model_gateway[0].name
  revision              = "1"
  display_name          = "Kestra Model Gateway"
  description           = "Governed model egress for Kestra workflow tasks."
  path                  = "model-gateway"
  protocols             = ["https"]
  service_url           = "${trimsuffix(azurerm_cognitive_account.model[0].endpoint, "/")}/openai/deployments/${azurerm_cognitive_deployment.model[0].name}"
  subscription_required = true
}

resource "azurerm_api_management_api_operation" "chat_completions" {
  count = var.enable_model_gateway ? 1 : 0

  operation_id        = "chat-completions"
  api_name            = azurerm_api_management_api.model_gateway[0].name
  api_management_name = azurerm_api_management.model_gateway[0].name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Create chat completion"
  description         = "Send an OpenAI-compatible chat completion request through the governed model gateway."
  method              = "POST"
  url_template        = "/chat/completions"

  response {
    status_code = 200
    description = "The model completion response."
  }
}

resource "azurerm_api_management_api_policy" "model_gateway" {
  count = var.enable_model_gateway ? 1 : 0

  api_name            = azurerm_api_management_api.model_gateway[0].name
  api_management_name = azurerm_api_management.model_gateway[0].name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = templatefile("${path.module}/model-gateway-policy.xml.tpl", {
    api_version          = var.model_api_version
    enable_observability = var.enable_model_gateway_observability
    rate_limit_calls     = var.model_gateway_rate_limit_calls
    rate_limit_period    = var.model_gateway_rate_limit_period
  })

  depends_on = [
    azurerm_api_management_api_diagnostic.model_gateway,
    azurerm_api_management_api_operation.chat_completions,
    azurerm_role_assignment.model_gateway,
    azapi_update_resource.model_gateway_diagnostic_metrics,
    azapi_update_resource.model_gateway_custom_metrics,
  ]
}

resource "azurerm_api_management_subscription" "model_gateway" {
  count = var.enable_model_gateway ? 1 : 0

  api_management_name = azurerm_api_management.model_gateway[0].name
  resource_group_name = azurerm_resource_group.rg.name
  api_id = trimsuffix(
    azurerm_api_management_api.model_gateway[0].id,
    ";rev=${azurerm_api_management_api.model_gateway[0].revision}",
  )
  display_name  = "Kestra workflow callers"
  state         = "active"
  allow_tracing = false

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_log_analytics_workspace" "model_gateway" {
  count = var.enable_model_gateway && var.enable_model_gateway_observability ? 1 : 0

  name                = "kestra-model-gw-${random_string.suffix.result}"
  location            = var.model_gateway_location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "model_gateway" {
  count = var.enable_model_gateway && var.enable_model_gateway_observability ? 1 : 0

  name                 = "kestra-model-gw-${random_string.suffix.result}"
  location             = var.model_gateway_location
  resource_group_name  = azurerm_resource_group.rg.name
  workspace_id         = azurerm_log_analytics_workspace.model_gateway[0].id
  application_type     = "web"
  daily_data_cap_in_gb = 1
}

resource "azapi_update_resource" "model_gateway_custom_metrics" {
  count = var.enable_model_gateway && var.enable_model_gateway_observability ? 1 : 0

  type        = "Microsoft.Insights/components@2020-02-02"
  resource_id = azurerm_application_insights.model_gateway[0].id

  body = {
    properties = {
      CustomMetricsOptedInType = "WithDimensions"
    }
  }
}

resource "azurerm_api_management_logger" "model_gateway" {
  count = var.enable_model_gateway && var.enable_model_gateway_observability ? 1 : 0

  name                = "kestra-model-gateway"
  api_management_name = azurerm_api_management.model_gateway[0].name
  resource_group_name = azurerm_resource_group.rg.name
  resource_id         = azurerm_application_insights.model_gateway[0].id

  application_insights {
    connection_string = azurerm_application_insights.model_gateway[0].connection_string
  }
}

resource "azurerm_api_management_api_diagnostic" "model_gateway" {
  count = var.enable_model_gateway && var.enable_model_gateway_observability ? 1 : 0

  identifier               = "applicationinsights"
  resource_group_name      = azurerm_resource_group.rg.name
  api_management_name      = azurerm_api_management.model_gateway[0].name
  api_name                 = azurerm_api_management_api.model_gateway[0].name
  api_management_logger_id = azurerm_api_management_logger.model_gateway[0].id

  sampling_percentage       = 100
  always_log_errors         = true
  log_client_ip             = true
  http_correlation_protocol = "W3C"
  verbosity                 = "information"

  frontend_request {
    body_bytes     = 0
    headers_to_log = ["x-kestra-correlation-id"]
  }

  frontend_response {
    body_bytes     = 0
    headers_to_log = ["x-kestra-correlation-id", "x-ratelimit-remaining-calls"]
  }

  backend_request {
    body_bytes     = 0
    headers_to_log = ["x-kestra-correlation-id"]
  }

  backend_response {
    body_bytes     = 0
    headers_to_log = ["x-kestra-correlation-id", "x-ratelimit-remaining-calls"]
  }
}

resource "azapi_update_resource" "model_gateway_diagnostic_metrics" {
  count = var.enable_model_gateway && var.enable_model_gateway_observability ? 1 : 0

  type        = "Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01"
  resource_id = azurerm_api_management_api_diagnostic.model_gateway[0].id

  body = {
    properties = {
      metrics = true
    }
  }

  ignore_missing_property = false
}
