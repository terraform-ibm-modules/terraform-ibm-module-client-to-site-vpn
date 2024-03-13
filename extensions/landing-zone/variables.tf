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
  description = "A unique identifier for resources. Must begin with a lowercase letter and end with a lowercase letter or number. This prefix will be prepended to any resources provisioned by this template."
}

variable "resource_group" {
  type        = string
  description = "An existing resource group name to use for this example. If not specified, a new resource group is created."
  default     = null
}

variable "base_vpn_gateway_name" {
  type        = string
  description = "The name of the VPN."
  default     = "vpn"
}

##############################################################
# Secret Manager
##############################################################

variable "sm_service_plan" {
  type        = string
  description = "The service/pricing plan to use when provisioning a new Secrets Manager instance. Allowed values: `standard` and `trial`. Only used if `provision_sm_instance` is set to true."
  default     = "standard"
}

variable "existing_sm_instance_guid" {
  type        = string
  description = "An existing Secrets Manager GUID. The existing Secret Manager instance must have private certificate engine configured. If not provided an new instance will be provisioned."
  default     = null
}

variable "existing_sm_instance_region" {
  type        = string
  description = "Required if value is passed into `var.existing_sm_instance_guid`."
  default     = null
}

variable "root_ca_name" {
  type        = string
  description = "The name of the Root CA to create for a private_cert secret engine. Only used when `var.existing_sm_instance_guid` is `false`."
  default     = "root-ca"
}

variable "root_ca_common_name" {
  type        = string
  description = "A fully qualified domain name or host domain name for the certificate to be created."
  default     = "example.com"
}

variable "intermediate_ca_name" {
  type        = string
  description = "The name of the Intermediate CA to create for a private_cert secret engine. Only used when `var.existing_sm_instance_guid` is `false`."
  default     = "intermediate-ca"
}

variable "certificate_template_name" {
  type        = string
  description = "The name of the Certificate Template to create for a private_cert secret engine. When `var.existing_sm_instance_guid` is `true`, then it has to be the existing template name that exists in the private cert engine."
  default     = "my-template"
}

variable "cert_common_name" {
  type        = string
  description = "A fully qualified domain name or host domain name for the certificate to be created."
}

variable "create_policy" {
  description = "Whether to create a new access group (using the value of `var.access_group_name`) with a VPN Client role."
  type        = bool
  default     = true
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

##############################################################
# VPC Landing Zone Targeting
##############################################################

variable "landing_zone_prefix" {
  type        = string
  description = "(Optional) Prefix that was used in the landing zone module. This value is used to lookup the landing zone management VPC in the region. Mutually exclusive with `var.vpc_id`."
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "(Optional) Id of the VPC in which the VPN infrastructure will be created. Target the landing-zone management VPC. Mutually exclusive with the `var.landing-zone-prefix` variable"
  default     = null
}

variable "landing_zone_network_cidr" {
  type        = string
  description = "The network CIDR of the landing zone deployment"
  default     = "10.0.0.0/8"
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

variable "adjust_landing_zone_acls" {
  type        = bool
  description = "If true (default), module will update the landing-zone acl to allow inbound/outbound traffic to the vpn client ips."
  default     = true
}

variable "existing_subnet_names" {
  description = "Optionally pass a list of existing subnet names (supports a maximum of 2) to use for the client-to-site VPN. If no subnets passed, new subnets will be created using the CIDR ranges specified in the `var.vpn_subnet_cidr_zone_1` and `var.vpn_subnet_cidr_zone_2` variables."
  type        = list(string)
  default     = []

  validation {
    error_message = "`var.existing_subnet_names` supports a maximum of 2 subnets."
    condition     = (length(var.existing_subnet_names) == 0 || length(var.existing_subnet_names) < 3)
  }
}
