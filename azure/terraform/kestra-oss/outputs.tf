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
