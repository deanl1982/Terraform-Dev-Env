##########################################################
## Join VM to Active Directory Domain
##########################################################

resource "azurerm_virtual_machine_extension" "join-domain" {
  name                 = "join-domain"
  #location             = "${var.location}"
  #resource_group_name  = "${var.resource_group_name}"
  #virtual_machine_name = "${var.vmname}"
  virtual_machine_id = "${var.vmid}"
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"
  

  # NOTE: the `OUPath` field is intentionally blank, to put it in the Computers OU
  settings = <<SETTINGS
    {
        "Name": "${var.active_directory_domain}",
        "OUPath": "",
        "User": "${var.active_directory_domain}\\${var.active_directory_username}",
        "Restart": "true",
        "Options": "3"
    }
SETTINGS

  protected_settings = <<SETTINGS
    {
        "Password": "${var.active_directory_password}"
    }
SETTINGS
}