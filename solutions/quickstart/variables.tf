variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud platform API key needed to deploy resources."
  sensitive   = true
}

variable "prefix" {
  type        = string
  description = "Optional. The prefix to append to all resources that this solution creates. Must begin with a letter and contain only lowercase letters, numbers, and - characters. Prefix is ignored if it is `null` or empty string (\"\")."
  default     = "quickstart"

  validation {
    error_message = "Prefix must begin with a letter and contain only lowercase letters, numbers, and - characters."
    condition     = var.prefix == null || var.prefix == "" ? true : can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

variable "resource_group_name" {
  type        = string
  description = "The name of a new or the existing resource group to provision the client to site VPN. If a prefix input variable is passed, it is prefixed to the value in the `<prefix>-value` format."
}

variable "use_existing_resource_group" {
  type        = bool
  description = "Whether to use an existing resource group."
  default     = false
}

variable "vpn_name" {
  type        = string
  description = "The name of the VPN. If a prefix input variable is passed, it is prefixed to the value in the `<prefix>-value` format."
  default     = "cts-vpn"
  nullable    = false
}

##############################################################################
# Secrets Manager resources
##############################################################################

variable "existing_secrets_manager_instance_crn" {
  type        = string
  description = "The CRN of existing secrets manager where the new private certificate will be created."
}

variable "cert_common_name" {
  type        = string
  description = "A fully qualified domain name or host domain name for the certificate to be created."
}

variable "certificate_template_name" {
  type        = string
  description = "The existing template name that exists in the private cert engine."
}

##############################################################################
# client-to-site VPN
##############################################################################

variable "vpn_client_access_group_users" {
  description = "The list of users in the Client to Site VPN Access Group"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "existing_vpc_crn" {
  type        = string
  description = "Crn of the VPC in which the VPN infrastructure will be created."
}

variable "vpn_client_access_acl_ids" {
  type        = list(string)
  description = "List of existing ACL rules IDs to which VPN connection rules is added."
  default     = []
  nullable    = false
}

##############################################################################
# Provider
##############################################################################

variable "provider_visibility" {
  description = "Set the visibility value for the IBM terraform provider. Supported values are `public`, `private`, `public-and-private`. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/guides/custom-service-endpoints)."
  type        = string
  default     = "private"
  nullable    = false

  validation {
    condition     = contains(["public", "private", "public-and-private"], var.provider_visibility)
    error_message = "Invalid visibility option. Allowed values are 'public', 'private', or 'public-and-private'."
  }
}
