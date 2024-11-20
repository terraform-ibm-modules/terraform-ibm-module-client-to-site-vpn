provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = module.existing_sm_crn_parser.region
  alias            = "ibm-sm"
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}
