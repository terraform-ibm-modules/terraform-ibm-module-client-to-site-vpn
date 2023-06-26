terraform {
  required_version = ">= 1.0.0"
  required_providers {
    # Use latest version of provider in non-basic examples to verify latest version works with module
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.54.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "1.18.0"
    }
  }
}
