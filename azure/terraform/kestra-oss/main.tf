# terraform apply \
#   -var="subscription_id=<azure_subscription>" \
#   -var="ssh_public_key=$(cat <path_to_pub_key>)" \
#   -var="postgres_password=<custom_password>" \
#   -var='kestra_password=<custom_password>' \
#   -var='authorized_source_ip=<trusted_ip_or_cidr>'

provider "azurerm" {
  features {}
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.Cdn",
    "Microsoft.Compute",
    "Microsoft.DBforPostgreSQL",
    "Microsoft.Network",
    "Microsoft.Storage",
  ]
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_virtual_network" "vnet" {
  name                = "kestra-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "vm_subnet" {
  name                 = "kestra-subnet-vm"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "db_subnet" {
  name                 = "kestra-subnet-db"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "fs"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "kestra-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.authorized_source_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowKestraWeb"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = var.authorized_source_ip
    destination_address_prefix = "*"
  }

  dynamic "security_rule" {
    for_each = var.enable_front_door ? [1] : []

    content {
      name                       = "AllowAzureFrontDoor"
      priority                   = 1020
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8080"
      source_address_prefix      = "AzureFrontDoor.Backend"
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_link" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_private_dns_zone" "dns" {
  name                = "kestra.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "kestra-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.rg.name
}

resource "azurerm_postgresql_flexible_server" "db" {
  name                = "kestra-db-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  version             = "16"
  delegated_subnet_id = azurerm_subnet.db_subnet.id
  private_dns_zone_id = azurerm_private_dns_zone.dns.id

  public_network_access_enabled = false

  administrator_login    = "kestra"
  administrator_password = var.postgres_password
  storage_mb             = 32768

  sku_name = var.db_sku_name

  lifecycle {
    ignore_changes = [zone]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.dns_link]
}

resource "azurerm_postgresql_flexible_server_database" "kestra_db" {
  name      = "kestra"
  server_id = azurerm_postgresql_flexible_server.db.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

resource "azurerm_storage_account" "store" {
  name                            = "kestrastore${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_container" "container" {
  name                  = "kestra-storage"
  storage_account_id    = azurerm_storage_account.store.id
  container_access_type = "private"
}

resource "azurerm_public_ip" "pip" {
  name                = "kestra-ip-std"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "kestra-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "kestra-vm"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.vm_size
  admin_username                  = var.admin_vm_username
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_vm_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/startup.sh.tpl", {
    admin_username         = var.admin_vm_username
    db_host                = azurerm_postgresql_flexible_server.db.fqdn
    db_name                = azurerm_postgresql_flexible_server_database.kestra_db.name
    db_admin               = "kestra"
    db_password            = var.postgres_password
    kestra_password        = var.kestra_password
    storage_account_name   = azurerm_storage_account.store.name
    storage_container_name = azurerm_storage_container.container.name
    storage_account_key    = azurerm_storage_account.store.primary_access_key
    kestra_image           = var.kestra_image
  }))
}

resource "azurerm_cdn_frontdoor_profile" "kestra" {
  count = var.enable_front_door ? 1 : 0

  name                     = "kestra-frontdoor-${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  sku_name                 = var.front_door_sku_name
  response_timeout_seconds = 120
}

resource "azurerm_cdn_frontdoor_endpoint" "kestra" {
  count = var.enable_front_door ? 1 : 0

  name                     = "kestra-${random_string.suffix.result}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.kestra[0].id
}

resource "azurerm_cdn_frontdoor_origin_group" "kestra" {
  count = var.enable_front_door ? 1 : 0

  name                     = "kestra-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.kestra[0].id

  health_probe {
    interval_in_seconds = 30
    path                = "/ping"
    protocol            = "Http"
    request_type        = "GET"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "kestra" {
  count = var.enable_front_door ? 1 : 0

  name                          = "kestra-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.kestra[0].id
  enabled                       = true

  certificate_name_check_enabled = false
  host_name                      = azurerm_public_ip.pip.ip_address
  http_port                      = 8080
  origin_host_header             = azurerm_public_ip.pip.ip_address
  priority                       = 1
  weight                         = 1000
}

resource "azurerm_cdn_frontdoor_route" "kestra" {
  count = var.enable_front_door ? 1 : 0

  name                          = "kestra-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.kestra[0].id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.kestra[0].id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.kestra[0].id]

  enabled                = true
  forwarding_protocol    = "HttpOnly"
  https_redirect_enabled = true
  link_to_default_domain = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]
}
