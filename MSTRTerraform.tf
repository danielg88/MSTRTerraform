# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "myterraformgroup" {
    name     = var.resource_group_name
    location = var.azure_region

    tags = {
        environment = "Terraform Deploy"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = format("%sVNET", var.resource_group_name)
    address_space       = ["10.0.0.0/16"]
    location            = var.azure_region
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    tags = {
        environment = "Terraform Deploy"
    }
}

# Create subnet for MSTR machines
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = format("%sSubnet", var.resource_group_name)
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    count = length(var.VMachines)
    name                = format("%sNetworkSecurityGroup", count.index)
    location            = var.azure_region
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Deploy"
    }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    count = length(var.VMachines)
    name                      = format("%sNIC", count.index)
    location                  = var.azure_region
    resource_group_name       = azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "${count.index}-myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "Terraform Deploy"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    count = length(azurerm_network_interface.myterraformnic)
    network_interface_id      = element(azurerm_network_interface.myterraformnic.*.id, count.index)
    network_security_group_id = element(azurerm_network_security_group.myterraformnsg.*.id, count.index) #azurerm_network_security_group.myterraformnsg.id
}

# Create virtual machine with CentOS and assigns labels for use with Ansible
resource "azurerm_linux_virtual_machine" "myterraformvm" {
    count = length(var.VMachines)
    name                  = format("%sVM", element(var.VMachines.*.name, count.index))
    location              = var.azure_region
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [element(azurerm_network_interface.myterraformnic.*.id, count.index)]
    size                  = element(var.VMachines.*.size, count.index)

    os_disk {
        name              = format("%smyOSDisk", element(var.VMachines.*.name, count.index))
        caching           = "ReadWrite"
        storage_account_type = "Standard_LRS"
        disk_size_gb = "64"
    }

    source_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS"
        sku       = "8_3"
        version   = "latest"
    }

    computer_name  = element(var.VMachines.*.name, count.index)
    admin_username = "mstr"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "mstr"
        public_key     = file("~/.ssh/id_rsa.pub")
    }

    tags = {
        environment = "Terraform Deploy"
        Ansible = element(var.VMachines.*.role, count.index)
    }
}

#Creates subnet for Application Gateway
resource "azurerm_subnet" "frontend" {
  name                 = "frontendSubnet"
  resource_group_name  = azurerm_resource_group.myterraformgroup.name
  virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
  address_prefixes     = ["10.0.2.0/24"]
}

#Creates the public IP for the Application Gateway
resource "azurerm_public_ip" "appgatewayIP" {
  name                = "appGatewayIP"
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  location            = var.azure_region
  allocation_method   = "Dynamic"
  domain_name_label   = "mstr-demo-architecture"
  
}

locals {
  backend_address_pool_name      = "appGateway-beap"
  frontend_port_name             = "appGateway-feport"
  frontend_ip_configuration_name = "appGateway-feip"
  http_setting_name              = "appGateway-be-htst"
  listener_name                  = "appGateway-httplstn"
  request_routing_rule_name      = "appGateway-rqrt"
  redirect_configuration_name    = "appGateway-rdrcfg"
}

#Creates App Gateway
resource "azurerm_application_gateway" "network" {
  name                = "web-appgateway"
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  location            = var.azure_region

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.frontend.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.appgatewayIP.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Enabled"
    port                  = 8080
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}

#Get NIC index of VM Machines with role webserver auxiliary variable for next step
locals {
  looper      = [for indice, VM in var.VMachines : indice if VM.role == "webserver"] 
}

#Add webservers VMs NIC to App Gateway
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "appGatewayVMs" {
        count = length(local.looper)
        network_interface_id    = element(azurerm_network_interface.myterraformnic.*.id, element(local.looper, count.index))
        ip_configuration_name   = "${element(local.looper, count.index)}-myNicConfiguration"
        backend_address_pool_id = azurerm_application_gateway.network.backend_address_pool.0.id

}