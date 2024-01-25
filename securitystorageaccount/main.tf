provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example_rg" {
  name     = "Varma-resource-group"
  location = "East US"
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

resource "azurerm_storage_account" "example_sa" {
  name                     = "varma9storageaccount"
  resource_group_name      = azurerm_resource_group.example_rg.name
  location                 = azurerm_resource_group.example_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET"]
      allowed_origins    = ["*"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_storage_account_network_rules" "example_network_rules" {
  storage_account_id        = azurerm_storage_account.example_sa.id
  default_action            = "Deny"
  virtual_network_subnet_ids = [azurerm_subnet.example_subnet.id]
  ip_rules = ["110.235.227.37"]
}

resource "azurerm_storage_container" "example" {
  name                  = "mycontainer99"
  storage_account_name  = azurerm_storage_account.example_sa.name
  container_access_type = "private"
  depends_on = [azurerm_storage_account_network_rules.example_network_rules]
}

resource "azurerm_storage_blob" "example" {
  name                   = "exampleblob"
  storage_account_name   = azurerm_storage_account.example_sa.name
  storage_container_name = azurerm_storage_container.example.name
  type                   = "Block"
  source                 = "C:/Users/Admin/terraform9/datalakestorage/Orders.csv"

  lifecycle {
    prevent_destroy = false
  }
}


resource "azurerm_storage_management_policy" "example" {
  storage_account_id = azurerm_storage_account.example_sa.id

  rule {
    name    = "rule1"
    enabled = true

    filters {
      prefix_match = ["container1/prefix1"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 10
        tier_to_archive_after_days_since_modification_greater_than = 50
        delete_after_days_since_modification_greater_than          = 100
      }

      snapshot {
        delete_after_days_since_creation_greater_than = 30
      }
    }
  }
}
