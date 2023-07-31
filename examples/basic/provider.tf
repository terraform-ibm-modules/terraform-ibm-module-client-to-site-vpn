provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.secrets_manager_region
  alias            = "ibm-sm"
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}
