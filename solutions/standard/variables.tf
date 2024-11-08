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
  default     = "vpn"
}

##############################################################################
# Secrets Manager resources
##############################################################################

variable "existing_secrets_manager_instance_crn" {
  type        = string
  description = "The CRN of existing secrets manager to use to create service credential secrets."
}

variable "existing_secrets_manager_cert_crn" {
  type        = string
  description = "The CRN of existing secrets manager private certificate to use to create VPN."
  default     = null
}

variable "cert_common_name" {
  type        = string
  description = "A fully qualified domain name or host domain name for the certificate to be created.  Only used when `existing_secrets_manager_cert_crn` is `null`."
  default     = null
}

variable "root_ca_name" {
  type        = string
  description = "The name of the Root CA to create for a private_cert secret engine. Only used when `existing_secrets_manager_cert_crn` is `null`."
  default     = null
}

variable "root_ca_common_name" {
  type        = string
  description = "A fully qualified domain name or host domain name for the certificate to be created.  Only used when `existing_secrets_manager_cert_crn` is `null`."
  default     = null
}

variable "intermediate_ca_name" {
  type        = string
  description = "The name of the Intermediate CA to create for a private_cert secret engine. Only used when `existing_secrets_manager_cert_crn` is `null`."
  default     = null
}

variable "certificate_template_name" {
  type        = string
  description = "The name of the Certificate Template to create for a private_cert secret engine. When `existing_secrets_manager_cert_crn` is `null`, then it has to be the existing template name that exists in the private cert engine."
  default     = null
}

##############################################################################
# client-to-site VPN
##############################################################################

variable "existing_subnet_names" {
  description = "Optionally pass a list of existing subnet names (supports a maximum of 2) to use for the client-to-site VPN. If no subnets passed, new subnets will be created using the CIDR ranges specified in the `var.vpn_subnet_cidr_zone_1` and `var.vpn_subnet_cidr_zone_2` variables."
  type        = list(string)
  default     = []

  validation {
    error_message = "`var.existing_subnet_names` supports a maximum of 2 subnets."
    condition     = (length(var.existing_subnet_names) == 0 || length(var.existing_subnet_names) < 3)
  }
}

variable "vpn_subnet_cidr_zone_1" {
  type        = string
  description = "The CIDR range to use from the first zone in the region (or zone specified in the `var.vpn_zone_1` variable)"
  default     = "10.10.40.0/24"
}

variable "vpn_subnet_cidr_zone_2" {
  type        = string
  description = "The CIDR range to use from the second zone in the region (or zone specified in the `var.vpn_zone_2` variable). If not specified, VPN will only be deployed to a single zone (standalone deployment)."
  default     = null
}


variable "vpn_client_access_group_users" {
  description = "The list of users in the Client to Site VPN Access Group"
  type        = list(string)
  default     = []
}

variable "access_group_name" {
  type        = string
  description = "The name of the IAM Access Group to create if `var.create_policy` is `true`."
  default     = "client-to-site-vpn-access-group"
}

variable "create_policy" {
  description = "Whether to create a new access group (using the value of `var.access_group_name`) with a VPN Client role."
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
  description = "(Optional) Crn of the VPC in which the VPN infrastructure will be created."
  default     = "crn:v1:bluemix:public:is:us-south:a/abac0df06b644a9cabc6e44f55b3880e::vpc:r006-bb73fb4f-7567-4f9b-bdc7-409d157db384"
}

variable "adjust_existing_vpc_acls" {
  type        = bool
  description = "If true (default), module will update the existing acl to allow inbound/outbound traffic to the vpn client ips."
  default     = true
}

variable "vpn_zone_1" {
  type        = string
  description = "Optionally specify the first zone where the VPN gateway will be created. If not specified, it will default to the first zone in the region."
  default     = null
}

variable "vpn_zone_2" {
  type        = string
  description = "Optionally specify the second zone where the VPN gateway will be created. If not specified, it will default to the second zone in the region but only if you have specified a value for `var.vpn_subnet_cidr_zone_2`."
  default     = null
}

variable "adjust_existing_subnet_name" {
  type        = string
  description = "The name of existing VPC subnet which will have updated acl to allow inbound/outbound traffic to the vpn client ips. Default value of landing zone VPN subnet is 'vpn-zone-1'"
  default     = "vpn-zone-1"
}

variable "adjust_network_cidr" {
  type        = string
  description = "The network CIDR which will be adjusted to o allow inbound/outbound traffic to the vpn client ips. Default value of the landing zone network CIDR is '10.0.0.0/8'"
  default     = "10.0.0.0/8"
}
