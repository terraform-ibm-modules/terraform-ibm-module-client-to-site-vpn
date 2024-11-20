variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud platform API key needed to deploy IAM enabled resources."
  sensitive   = true
}

variable "region" {
  type        = string
  description = "The region where the resources are created."
}

variable "prefix" {
  type        = string
  description = "Optional. The prefix to append to all resources that this solution creates. Must begin with a lowercase letter and end with a lowercase letter or number."
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

variable "name" {
  type        = string
  description = "The name of the VPN."
  default     = "cts-vpn"
}

##############################################################################
# Secrets Manager resources
##############################################################################

variable "existing_secrets_manager_instance_crn" {
  type        = string
  description = "The CRN of existing secrets manager where the certificate to use for the VPN is stored or where the new certificate will be created."
}

variable "existing_secrets_manager_cert_crn" {
  type        = string
  description = "The CRN of existing secrets manager private certificate to use to create VPN. If the value is null, then new private certificate is created."
  default     = null
}

variable "cert_common_name" {
  type        = string
  description = "A fully qualified domain name or host domain name for the certificate to be created.  Only used when `existing_secrets_manager_cert_crn` is `null`."
  default     = null
}

variable "certificate_template_name" {
  type        = string
  description = "The name of the Certificate Template to create for a private_cert secret engine. When `existing_secrets_manager_cert_crn` is `null`, then it has to be the existing template name that exists in the private cert engine."
  default     = null
}

variable "existing_secrets_manager_secret_group_id" {
  type        = string
  description = "The CRN of existing secrets manager secret group id used for new created certificate. If the value is null, then new secrets manager secret group is created."
  default     = null
}

##############################################################################
# client-to-site VPN
##############################################################################

variable "vpn_subnet_cidr_zone_1" {
  type        = string
  description = "The CIDR range to use from the first zone in the region (or zone specified in the 'vpn_zone_1' input variable)"
  default     = "10.10.40.0/24"
}

variable "vpn_client_access_group_users" {
  description = "The list of users in the Client to Site VPN Access Group"
  type        = list(string)
  default     = []
}

variable "access_group_name" {
  type        = string
  description = "The name of the IAM Access Group to create if the 'create_policy' input variable is `true`."
  default     = "client-to-site-vpn-access-group"
}

variable "create_policy" {
  description = "Whether to create a new access group (using the value of the 'access_group_name' input variable) with a VPN Client role."
  type        = bool
  default     = true
}

variable "vpn_server_routes" {
  type = map(object({
    destination = string
    action      = string
  }))
  description = "A map of server routes to be added to created VPN server."
  default = {
    "vpc-10" = {
      destination = "10.0.0.0/8"
      action      = "deliver"
    },
    # Add route for PaaS IBM Cloud backbone. This is mostly used to give access to the Kube master endpoints.
    "vpc-166" = {
      destination = "166.8.0.0/14"
      action      = "deliver"
    }
  }
}

variable "existing_vpc_crn" {
  type        = string
  description = "Crn of the VPC in which the VPN infrastructure will be created."
}

variable "vpn_zone_1" {
  type        = string
  description = "Optionally specify the first zone where the VPN gateway will be created. If not specified, it will default to the first zone in the region."
  default     = null
}
