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
  client_id       = "b241a7e5-0fcb-4127-b905-13b744454f54"
  client_secret   = "udz8Q~TUXi6jnzDVjFbgL47LqKcXYBVzfoZ5Nc4Z"
  tenant_id       = "6dcbf8bf-e602-41e8-af24-bf34dde79e7e"
  subscription_id = "6c9ed132-0071-496b-bae9-2fe73ffafbd1"
  
}
 
provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.example.id
}



variable "storage_account_name" {
  default = "varma9storageaccount"
}

variable "location" {
  default = "East US"
}

variable "container_name" {
  default = "rawdata"
}

variable "local_csv_file_path" {
  default = "C:/Users/Admin/terraform9/datalakestorage/Orders.csv"
}



resource "azurerm_resource_group" "example" {
  name     = "varma-resource-group"
  location = "East US"
}



# Create a storage account
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.example.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}



# Create a container
resource "azurerm_storage_container" "container" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"

}



# Upload the .csv file to the container
resource "azurerm_storage_blob" "blob" {
  name                   = "Orders.csv"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.container.name
  type                   = "Block"
  source                 = var.local_csv_file_path
}

output "blob_url" {
  value = azurerm_storage_blob.blob.url
} 


resource "azurerm_databricks_workspace" "example" {
  name                = "example-databricks-workspace"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "standard"
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

 
resource "databricks_notebook" "example" {
  depends_on = [databricks_cluster.example]
  path       = "/Shared/ReadCSVNotebook"
  language   = "PYTHON"
  content_base64 = base64encode(<<-EOT
   #Storage account and key you will get it from the portal as shown in the Cookbook Recipe.
storageAccount="******"
storageKey ="*******"
mountpoint = "/mnt/Blob"
storageEndpoint =   "wasbs://rawdata@{}.blob.core.windows.net".format(storageAccount)
storageConnSting = "fs.azure.account.key.{}.blob.core.windows.net".format(storageAccount)

try:
  dbutils.fs.mount(
  source = storageEndpoint,
  mount_point = mountpoint,
  extra_configs = {storageConnSting:storageKey})
except:
    print("Already mounted...."+mountpoint)

  EOT
  )
}




output "notebook_url" {
  value = databricks_notebook.example.url
}


