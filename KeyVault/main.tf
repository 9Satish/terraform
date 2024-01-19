# main.tf

provider "azurerm" {
  features {}
}

# Data Block to retrieve current Azure client configuration
data "azurerm_client_config" "current" {}

# Resource Group (updated to handle existing resource group)
resource "azurerm_resource_group" "example" {
  name     = "VarmaResourceGroup"
  location = "East US"

  # Import existing resource group into Terraform state
  lifecycle {
    ignore_changes = [tags]  # Ignore tags during import
  }
}

# Storage Account
resource "azurerm_storage_account" "example" {
  name                     = "varma9storageaccount"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Key Vault
resource "azurerm_key_vault" "example" {
  name                        = "varma9keyvault"
  resource_group_name         = azurerm_resource_group.example.name
  location                    = azurerm_resource_group.example.location
  enabled_for_disk_encryption = true
  enabled_for_deployment      = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
}

# Assign Key Vault Administrator Role
resource "azurerm_role_assignment" "example" {
  scope                = azurerm_key_vault.example.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Assign Key Vault Permissions
resource "azurerm_key_vault_access_policy" "example" {
  key_vault_id      = azurerm_key_vault.example.id
  tenant_id         = data.azurerm_client_config.current.tenant_id
  object_id         = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get", "Set", "List","Delete"]
}

# Storage Account Key
data "azurerm_storage_account" "example" {
  name                = azurerm_storage_account.example.name
  resource_group_name = azurerm_resource_group.example.name
}

# Storage Account Key Secret in Key Vault
resource "azurerm_key_vault_secret" "example" {
  name         = "StorageAccountKey"
  value        = data.azurerm_storage_account.example.primary_access_key
  key_vault_id = azurerm_key_vault.example.id
}
