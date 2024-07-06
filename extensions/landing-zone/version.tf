terraform {
  required_version = ">= 1.0.0"
  required_providers {
    # Locking into an exact version for a deployable architecture
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.67.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.11.2"
    }
  }
}
