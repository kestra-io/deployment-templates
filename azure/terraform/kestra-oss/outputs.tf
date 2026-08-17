output "kestra_url" {
  value = var.enable_front_door ? "https://${azurerm_cdn_frontdoor_endpoint.kestra[0].host_name}" : "http://${azurerm_public_ip.pip.ip_address}:8080"
}

output "kestra_origin_url" {
  value = "http://${azurerm_public_ip.pip.ip_address}:8080"
}

output "ssh_command" {
  value = "ssh ${var.admin_vm_username}@${azurerm_public_ip.pip.ip_address}"
}

output "db_hostname" {
  value = azurerm_postgresql_flexible_server.db.fqdn
}

output "model_gateway_url" {
  value = var.enable_model_gateway ? "${azurerm_api_management.model_gateway[0].gateway_url}/${azurerm_api_management_api.model_gateway[0].path}" : null
}

output "model_gateway_chat_completions_url" {
  value = var.enable_model_gateway ? "${azurerm_api_management.model_gateway[0].gateway_url}/${azurerm_api_management_api.model_gateway[0].path}/chat/completions" : null
}

output "model_gateway_subscription_key" {
  value     = var.enable_model_gateway ? azurerm_api_management_subscription.model_gateway[0].primary_key : null
  sensitive = true
}
