provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = module.secrets_manager.secrets_manager_region
  alias            = "ibm-sm"
}
