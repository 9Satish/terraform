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


# Create a virtual network
resource "azurerm_virtual_network" "example_vnet" {
  name                = "VNet99"
  address_space       = ["10.0.0.0/16"] # Example address space
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

# Create a subnet within the virtual network
resource "azurerm_subnet" "example_subnet" {
  name                 = "subnet99"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example_vnet.name
  address_prefixes     = ["10.0.1.0/24"] # Example subnet range

  service_endpoints = ["Microsoft.Storage","Microsoft.KeyVault"]
}

# Create a network security group
resource "azurerm_network_security_group" "example_nsg" {
  name                = "VN9-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

# Associate the network security group with the subnet
resource "azurerm_subnet_network_security_group_association" "example_association" {
  subnet_id                 = azurerm_subnet.example_subnet.id
  network_security_group_id = azurerm_network_security_group.example_nsg.id
}

# Storage Account
resource "azurerm_storage_account" "example" {
  name                     = "varma9storageaccount"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
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
  storage_account_id        = azurerm_storage_account.example.id
  default_action            = "Deny"
  virtual_network_subnet_ids = [azurerm_subnet.example_subnet.id]
  ip_rules = ["183.82.97.65"]
}

# Create a container
resource "azurerm_storage_container" "container" {
  name                  = "rawdata9"
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

resource "azurerm_storage_management_policy" "example" {
  storage_account_id = azurerm_storage_account.example.id

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

# Key Vault 
resource "azurerm_key_vault" "example" {
  name                        = "malladi9keyvault"
  resource_group_name         = azurerm_resource_group.example.name
  location                    = azurerm_resource_group.example.location
  enabled_for_disk_encryption = true
  enabled_for_deployment      = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  
  network_acls {
    bypass           = "AzureServices"
    default_action   = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.example_subnet.id]
    ip_rules = ["183.82.97.65"]
  }
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
  secret_permissions = ["Get", "Set", "List", "Delete"]
}



# Storage Account Key
data "azurerm_storage_account" "example" {
  name                = azurerm_storage_account.example.name
  resource_group_name = azurerm_resource_group.example.name
}

# Storage Account Key Secret in Key Vault
resource "azurerm_key_vault_secret" "example" {
  name         = "malladi9secret"
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

   storageAccount = "varma9storageaccount"
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


resource "azurerm_databricks_virtual_network_peering" "example" {
  name                = "databricks-vnet-peer"
  resource_group_name = azurerm_resource_group.example.name
  workspace_id        = azurerm_databricks_workspace.example.id

  remote_address_space_prefixes = azurerm_virtual_network.example_vnet.address_space
  remote_virtual_network_id     = azurerm_virtual_network.example_vnet.id
  allow_virtual_network_access  = true
}

resource "azurerm_virtual_network_peering" "remote" {
  name                         = "peer-to-databricks"
  resource_group_name          = azurerm_resource_group.example.name
  virtual_network_name         = azurerm_virtual_network.example_vnet.name
  remote_virtual_network_id    = azurerm_databricks_virtual_network_peering.example.virtual_network_id
  allow_virtual_network_access = true
}
