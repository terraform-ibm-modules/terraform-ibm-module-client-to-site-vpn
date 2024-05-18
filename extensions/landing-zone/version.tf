terraform {
  required_version = ">= 1.0.0, <1.7.0"
  required_providers {
    # Locking into an exact version for a deployable architecture
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.65.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.11.1"
    }
  }
}
