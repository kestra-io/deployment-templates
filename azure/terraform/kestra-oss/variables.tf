variable "subscription_id" {
  description = "The Azure Subscription ID to deploy resources into"
}

variable "location" {
  description = "Azure region"
  default     = "West Europe"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  default     = "kestra-terraform-rg"
}

variable "admin_vm_username" {
  description = "VM Admin Username"
  default     = "kestra"
}

variable "ssh_public_key" {
  description = "SSH Public Key"
}

variable "postgres_password" {
  description = "Password for the PostgreSQL database"
  sensitive   = true
}

variable "kestra_password" {
  description = "Password for Kestra Web UI"
  sensitive   = true
}

variable "kestra_encryption_key" {
  description = "Optional base64-encoded 256-bit key for encrypting Kestra SECRET inputs and outputs; Terraform generates one when omitted"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.kestra_encryption_key == null || length(var.kestra_encryption_key) >= 32
    error_message = "kestra_encryption_key must contain at least 32 characters when provided."
  }
}

variable "authorized_source_ip" {
  description = "Trusted IP address or CIDR allowed to access SSH and the Kestra web interface"
}

variable "db_sku_name" {
  description = "The SKU Name for the PostgreSQL Flexible Server. Examples: B_Standard_B1ms, GP_Standard_D2ds_v4, MO_Standard_E4s_v3"
  default     = "B_Standard_B1ms"
}

variable "vm_size" {
  description = "Azure VM size used to run Kestra"
  default     = "Standard_B2s"
}

variable "kestra_image" {
  description = "Immutable Kestra container image to run; update deliberately after testing a newer release"
  default     = "kestra/kestra:v1.3.33"
}

variable "enable_front_door" {
  description = "Expose Kestra through an Azure Front Door managed HTTPS endpoint"
  type        = bool
  default     = true
}

variable "front_door_sku_name" {
  description = "Azure Front Door SKU used for the managed HTTPS endpoint"
  type        = string
  default     = "Standard_AzureFrontDoor"

  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.front_door_sku_name)
    error_message = "front_door_sku_name must be Standard_AzureFrontDoor or Premium_AzureFrontDoor."
  }
}

variable "enable_model_gateway" {
  description = "Deploy API Management and Azure OpenAI as an optional governed model-egress gateway"
  type        = bool
  default     = false
}

variable "model_gateway_location" {
  description = "Azure region for API Management, Azure OpenAI, and model-gateway telemetry"
  type        = string
  default     = "East US 2"
}

variable "model_gateway_sku_name" {
  description = "API Management SKU; Consumption_0 is the cost-conscious validation tier, while production commonly uses StandardV2_1 or Premium_1"
  type        = string
  default     = "Consumption_0"
}

variable "model_gateway_publisher_name" {
  description = "API Management publisher name"
  type        = string
  default     = "Kestra"
}

variable "model_gateway_publisher_email" {
  description = "API Management publisher email"
  type        = string
  default     = "admin@kestra.io"
}

variable "model_gateway_rate_limit_calls" {
  description = "Maximum model requests per APIM subscription during each renewal period"
  type        = number
  default     = 60

  validation {
    condition     = var.model_gateway_rate_limit_calls > 0
    error_message = "model_gateway_rate_limit_calls must be greater than zero."
  }
}

variable "model_gateway_rate_limit_period" {
  description = "APIM request-rate renewal period in seconds"
  type        = number
  default     = 60

  validation {
    condition     = var.model_gateway_rate_limit_period > 0 && var.model_gateway_rate_limit_period <= 300
    error_message = "model_gateway_rate_limit_period must be between 1 and 300 seconds."
  }
}

variable "enable_model_gateway_observability" {
  description = "Send APIM diagnostics and LLM token metrics to Application Insights and Log Analytics"
  type        = bool
  default     = true
}

variable "model_deployment_name" {
  description = "Azure OpenAI deployment name"
  type        = string
  default     = "kestra-gpt-4-1-mini"
}

variable "model_name" {
  description = "Azure OpenAI model name"
  type        = string
  default     = "gpt-4.1-mini"
}

variable "model_version" {
  description = "Azure OpenAI model version"
  type        = string
  default     = "2025-04-14"
}

variable "model_sku_name" {
  description = "Azure OpenAI deployment SKU"
  type        = string
  default     = "Standard"
}

variable "model_capacity" {
  description = "Azure OpenAI deployment capacity in thousands of tokens per minute"
  type        = number
  default     = 10

  validation {
    condition     = var.model_capacity > 0
    error_message = "model_capacity must be greater than zero."
  }
}

variable "model_api_version" {
  description = "Azure OpenAI data-plane API version added by the APIM policy"
  type        = string
  default     = "2024-10-21"
}
