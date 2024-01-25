# main.tf

terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "1.33.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.example.id
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

# Create a container
resource "azurerm_storage_container" "container" {
  name                  = "rawdata"
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "private"

}

# Upload the .csv file to the container
resource "azurerm_storage_blob" "blob" {
  name                   = "Orders.csv"
  storage_account_name   = azurerm_storage_account.example.name
  storage_container_name = azurerm_storage_container.container.name
  type                   = "Block"
  source                 = "C:/Users/Admin/terraform9/datalakestorage/Orders.csv"
}

output "blob_url" {
  value = azurerm_storage_blob.blob.url
}

# Key Vault
resource "azurerm_key_vault" "example" {
  name                        = "devopsvault88"
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

# Grant Key Vault Get Permissions
resource "azurerm_role_assignment" "kv_permissions" {
  scope                = azurerm_key_vault.example.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Assign Key Vault Permissions
resource "azurerm_key_vault_access_policy" "example" {
  key_vault_id      = azurerm_key_vault.example.id
  tenant_id         = data.azurerm_client_config.current.tenant_id
  object_id         = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get","Set","List","Delete"]
}


# Storage Account Key
data "azurerm_storage_account" "example" {
  name                = azurerm_storage_account.example.name
  resource_group_name = azurerm_resource_group.example.name
}

# Storage Account Key Secret in Key Vault
resource "azurerm_key_vault_secret" "example" {
  name         = "demo99secret"
  value        = data.azurerm_storage_account.example.primary_access_key
  key_vault_id = azurerm_key_vault.example.id
}

resource "azurerm_databricks_workspace" "example" {
  name                = "example-databricks-workspace"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "trial"
}

 
resource "databricks_cluster" "example" {
  cluster_name            = "example-cluster"
  spark_version           = "7.3.x-scala2.12"
  node_type_id            = "Standard_DS3_v2"
  autotermination_minutes = 20
  autoscale {
    min_workers = 1
    max_workers = 2
  }
}

resource "databricks_secret_scope" "example" {
  name                     = "KeyVaultScope"
  initial_manage_principal = "users"
}

resource "databricks_secret" "example" {
  scope   = databricks_secret_scope.example.name
  key     = "blobstoragesecret"
  string_value = azurerm_key_vault_secret.example.value
}

 
resource "databricks_notebook" "example" {
  depends_on = [databricks_cluster.example]
  path       = "/Shared/ReadCSVNotebook"
  language   = "PYTHON"
  content_base64 = base64encode(<<-EOT
   # Storage account key is stored in Azure Key-Vault as a secret.
   # The secret name is blobstoragesecret, and KeyVaultScope is the name of the scope we have created.
   # We can also store the storage account name as a new secret if we don't want users to know the name of the storage account.

   # Set the secret scope and key
   key_vault_scope = "KeyVaultScope"
   secret_key = "blobstoragesecret"

   # Get the secret value
   storageKey = dbutils.secrets.get(scope=key_vault_scope, key=secret_key)

   storageAccount = "cookbookblobstorage1"
   mountpoint = "/mnt/KeyVaultBlob"
   storageEndpoint = "wasbs://rawdata@{}.blob.core.windows.net".format(storageAccount)
   storageConnSting = "fs.azure.account.key.{}.blob.core.windows.net".format(storageAccount)

   try:
     dbutils.fs.mount(
       source = storageEndpoint,
       mount_point = mountpoint,
       extra_configs = {storageConnSting:storageKey}
     )
   except:
     print("Already mounted...."+mountpoint)
  EOT
  )
}




output "notebook_url" {
  value = databricks_notebook.example.url
}
