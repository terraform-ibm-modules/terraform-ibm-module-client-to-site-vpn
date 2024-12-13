variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud platform API key needed to deploy resources."
  sensitive   = true
}

variable "prefix" {
  type        = string
  description = "Optional. The prefix to append to all resources that this solution creates. Must begin with a letter and contain only lowercase letters, numbers, and - characters. Prefix is ignored if it is `null` or empty string (\"\")."
  default     = "standard"

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
  nullable    = false
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
  description = "The CRN of existing secrets manager where the certificate to use for the VPN is stored or where the new certificate will be created."
}

variable "existing_secrets_manager_cert_crn" {
  type        = string
  description = "The CRN of existing secrets manager private certificate to use to create VPN. If the value is null, then new private certificate is created."
  default     = null
}

variable "existing_secrets_manager_secret_group_id" {
  type        = string
  description = "The CRN of existing secrets manager secret group id used for new created certificate. If the value is null, then new secrets manager secret group is created."
  default     = null
}

variable "cert_common_name" {
  type        = string
  description = "A fully qualified domain name or host domain name for the certificate to be created. Only used when `existing_secrets_manager_cert_crn` input variable is `null`."
  default     = null
}

variable "certificate_template_name" {
  type        = string
  description = "The name of the Certificate Template to create for a private certificate secret engine. When `existing_secrets_manager_cert_crn` input variable is `null`, then it has to be the existing template name that exists in the private cert engine."
  default     = null
}

##############################################################################
# client-to-site VPN
##############################################################################

variable "vpn_subnet_cidr_zone_1" {
  type        = string
  description = "The CIDR range to use for subnet creation from the first zone in the region (or zone specified in the 'vpn_zone_1' input variable). Ensure it's not conflicting with any existing subnets. Must be set if 'existing_subnet_ids' input variable is not set."
  default     = null
}

variable "vpn_subnet_cidr_zone_2" {
  type        = string
  description = "The CIDR range to use for subnet creation from the second zone in the region (or zone specified in the 'vpn_zone_2' input variable). Ensure it's not conflicting with any existing subnets. Must be set if 'existing_subnet_ids' input variable is not set."
  default     = null
}

variable "remote_cidr" {
  type        = string
  description = "The source CIDR block to use for creating ACL rule and security group (if add_security_group input variable is set to true). By default the deny all inbound and outbound ACL rule is created. Must be set if 'existing_subnet_ids' input variable is not set."
}

variable "add_security_group" {
  type        = bool
  description = "Add security group to a new VPN?"
  default     = true
  nullable    = false
}

variable "vpn_client_access_group_users" {
  description = "The list of users in the Client to Site VPN Access Group"
  type        = list(string)
  default     = []
  nullable    = false
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
  nullable    = false
}

variable "vpn_server_routes" {
  type        = list(string)
  description = "A map of server routes to be added to created VPN server. By default the route (166.8.0.0/14) for PaaS IBM Cloud backbone is added (mostly used to give access to the Kube master endpoints) and 161.26.0.0/16 (IaaS)."
  default     = []
  nullable    = false
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

variable "vpn_zone_2" {
  type        = string
  description = "Optionally specify the second zone where the VPN gateway will be created. If not specified, it will default to the second zone in the region."
  default     = null
}

variable "existing_subnet_ids" {
  type        = list(string)
  description = "Optionally pass a list of existing subnet ids (supports a maximum of 2) to use for the client-to-site VPN. If no subnets passed, new subnets will be created using the CIDR ranges specified in the 'vpn_subnet_cidr_zone_1' and 'vpn_subnet_cidr_zone_2' input variables. On existing subnets no ACL rules are set."
  nullable    = false
  default     = []

  validation {
    error_message = "The existing_subnet_ids input variable supports a maximum of 2 subnets."
    condition     = (length(var.existing_subnet_ids) == 0 || length(var.existing_subnet_ids) < 3)
  }
}

variable "client_ip_pool" {
  type        = string
  description = "The VPN client IPv4 address pool, expressed in CIDR format. The request must not overlap with any existing address prefixes in the VPC or any of the following reserved address ranges: - 127.0.0.0/8 (IPv4 loopback addresses) - 161.26.0.0/16 (IBM services) - 166.8.0.0/14 (Cloud Service Endpoints) - 169.254.0.0/16 (IPv4 link-local addresses) - 224.0.0.0/4 (IPv4 multicast addresses). The prefix length of the client IP address pool's CIDR must be between /9 (8,388,608 addresses) and /22 (1024 addresses). A CIDR block that contains twice the number of IP addresses that are required to enable the maximum number of concurrent connections is recommended."
  default     = "10.0.0.0/20"
  nullable    = false
}

variable "vpn_client_access_acl_ids" {
  type        = list(string)
  description = "List of existing ACL rule IDs to which VPN connection rules is added."
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
