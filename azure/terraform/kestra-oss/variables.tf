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
  description = "Kestra container image to run"
  default     = "kestra/kestra:latest"
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
