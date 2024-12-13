provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = module.existing_sm_crn_parser.region
  alias            = "ibm-sm"
  visibility       = var.provider_visibility
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = local.vpc_region
  visibility       = var.provider_visibility
}
