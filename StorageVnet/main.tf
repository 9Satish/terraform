provider "azurerm" {
  features {}
}
 
# Create a resource group
resource "azurerm_resource_group" "example_rg" {
  name     = "VarmaRG"
  location = "East US" # Example location
}
 
# Create a virtual network
resource "azurerm_virtual_network" "example_vnet" {
  name                = "VNet99"
  address_space       = ["10.0.0.0/16"] # Example address space
  location            = azurerm_resource_group.example_rg.location
  resource_group_name = azurerm_resource_group.example_rg.name
}
 
# Create a subnet within the virtual network
resource "azurerm_subnet" "example_subnet" {
  name                 = "subnet99"
  resource_group_name  = azurerm_resource_group.example_rg.name
  virtual_network_name = azurerm_virtual_network.example_vnet.name
  address_prefixes     = ["10.0.1.0/24"] # Example subnet range

  service_endpoints = ["Microsoft.Storage"]
}
 
# Create a network security group
resource "azurerm_network_security_group" "example_nsg" {
  name                = "VN9-nsg"
  location            = azurerm_resource_group.example_rg.location
  resource_group_name = azurerm_resource_group.example_rg.name
}
 
# Associate the network security group with the subnet
resource "azurerm_subnet_network_security_group_association" "example_association" {
  subnet_id                 = azurerm_subnet.example_subnet.id
  network_security_group_id = azurerm_network_security_group.example_nsg.id
}
 
# Create a storage account
resource "azurerm_storage_account" "example_sa" {
  name                     = "9blobstorage9" # Name must be unique and cannot contain hyphens
  resource_group_name      = azurerm_resource_group.example_rg.name
  location                 = azurerm_resource_group.example_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
 
resource "azurerm_storage_account_network_rules" "example_network_rules" {
  storage_account_id = azurerm_storage_account.example_sa.id

  default_action = "Deny"

  virtual_network_subnet_ids = [azurerm_subnet.example_subnet.id]
}


