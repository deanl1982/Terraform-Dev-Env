provider "azurerm" {
  features {}
}

# Remote State Config
# Keep the state file in seperate RG to the resources deployed
terraform {
  backend "azurerm" {
    storage_account_name = "vfftfstate"
    container_name       = "fullenvstate"
    key                  = "terraform.tfstate"
    resource_group_name  = "RG-TF-Testing"
  }
}

module "PromoteDC" {
  source                        = "../Modules/Promote-DC"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  vmname                        = azurerm_windows_virtual_machine.dc01.name
  vmid                          = azurerm_windows_virtual_machine.dc01.id
  active_directory_domain       = var.ADDomainName
  admin_password                = var.ADDomainPassword
  active_directory_netbios_name = var.ADDomainNetbios
}

module "MB01-Join-Domain" {
  source                    = "../Modules/AD-Join"
  resource_group_name       = azurerm_resource_group.main.name
  location                  = azurerm_resource_group.main.location
  vmname                    = azurerm_windows_virtual_machine.mb01.name
  vmid                      = azurerm_windows_virtual_machine.mb01.id
  active_directory_domain   = var.ADDomainName
  active_directory_password = var.ADDomainPassword
  active_directory_username = var.ADDomainUser
}

module "WVD01-Join-Domain" {
  source                    = "../Modules/AD-Join"
  resource_group_name       = azurerm_resource_group.main.name
  location                  = azurerm_resource_group.main.location
  vmname                    = azurerm_windows_virtual_machine.wvd01.name
  vmid                      = azurerm_windows_virtual_machine.wvd01.id
  active_directory_domain   = var.ADDomainName
  active_directory_password = var.ADDomainPassword
  active_directory_username = var.ADDomainUser
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = "West US 2"

  tags = {
    environment = "VFF-Dev-Test"
    customer    = "internal"
    costcode    = "VFF123"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_servers         = ["10.0.2.5"]
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "dc01nic" {
  name                = "${var.prefix}-dc01nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "dc01nicconf"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.5"
    public_ip_address_id          = azurerm_public_ip.DC01PubIP.id
  }
}

/*resource "azurerm_network_interface" "dc01nicpub" {
  name                = "${var.prefix}-dc01nicpub"
   location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
   name                          = "myNicConfiguration"
  subnet_id                     = azurerm_subnet.internal.id
  private_ip_address_allocation = "Dynamic"
  public_ip_address_id          = azurerm_public_ip.DC01PubIP.id
  }

  tags = {
    environment = "VFF-Dev-Test"
   customer    = "internal"
  costcode    = "VFF123"
  }
}*/

resource "azurerm_network_interface" "mb01nic" {
  name                = "${var.prefix}-mb01nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "mb01nicconf"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "wvd01nic" {
  name                = "${var.prefix}-wvd01nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "wvd01nicconf"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_public_ip" "DC01PubIP" {
  name                = "DC01PubIP"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"

  tags = {
    environment = "VFF-Dev-Test"
    customer    = "internal"
    costcode    = "VFF123"
  }
}

resource "azurerm_windows_virtual_machine" "dc01" {
  name                = "${var.prefix}-dc01"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2ms"
  admin_username      = var.ADDomainUser
  admin_password      = var.ADDomainPassword
  #availability_set_id = azurerm_availability_set.DemoAset.id
  network_interface_ids = [
    azurerm_network_interface.dc01nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_windows_virtual_machine" "mb01" {
  name                = "${var.prefix}-mb01"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2ms"
  admin_username      = var.ADDomainUser
  admin_password      = var.ADDomainPassword
  #availability_set_id = azurerm_availability_set.DemoAset.id
  network_interface_ids = [
    azurerm_network_interface.mb01nic.id,
  ]
  depends_on = [module.PromoteDC]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_windows_virtual_machine" "wvd01" {
  name                = "${var.prefix}-wvd01"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2ms"
  admin_username      = var.ADDomainUser
  admin_password      = var.ADDomainPassword
  #availability_set_id = azurerm_availability_set.DemoAset.id
  network_interface_ids = [
    azurerm_network_interface.wvd01nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  depends_on = [module.PromoteDC]

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "office-365"
    sku       = "20h1-evd-o365pp"
    version   = "latest"
  }
}