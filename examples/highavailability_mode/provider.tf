data "ibm_iam_auth_token" "tokendata" {}

provider "restapi" {
  uri                  = "https:"
  write_returns_object = true
  debug                = false
  headers = {
    Authorization = data.ibm_iam_auth_token.tokendata.iam_access_token
    Content-Type  = "application/json"
  }
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.existing_sm_instance_region == null ? var.region : var.existing_sm_instance_region
}
