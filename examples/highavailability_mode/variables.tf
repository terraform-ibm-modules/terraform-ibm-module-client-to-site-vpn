variable "ibmcloud_api_key" {
  type        = string
  description = "API key that is associated with the account to use."
  sensitive   = true
}

variable "region" {
  type        = string
  description = "Region to provision all resources created by this example."
  default     = "us-south"
}

variable "prefix" {
  type        = string
  description = "Prefix to append to all resources created by this example"
  default     = "tf-ibm"
}

variable "resource_group" {
  type        = string
  description = "Name of the resource group to use for this example. If not set, a resource group is created."
  default     = null
}

variable "resource_tags" {
  type        = list(string)
  description = "Optional list of tags to add to the created resources."
  default     = []
}

variable "base_vpn_gateway_name" {
  type        = string
  description = "Name of the VPN."
  default     = "vpn"
}

##############################################################
# Secret Manager
##############################################################
variable "sm_service_plan" {
  type        = string
  description = "Type of service plan to use to provision Secrets Manager."
  default     = "trial"
}

variable "existing_sm_instance_guid" {
  type        = string
  description = "Existing Secrets Manager GUID. The existing Secret Manager instance must have private certificate engine configured. If not provided an new instance will be provisioned."
  default     = null
}

variable "existing_sm_instance_region" {
  type        = string
  description = "Required if value is passed into var.existing_sm_instance_guid"
  default     = null
}

variable "root_ca_name" {
  type        = string
  description = "Name of the Root CA to create for a private_cert secret engine. Only used when var.existing_sm_instance_guid is false"
  default     = "root-ca"
}

variable "intermediate_ca_name" {
  type        = string
  description = "Name of the Intermediate CA to create for a private_cert secret engine. Only used when var.existing_sm_instance_guid is false"
  default     = "intermediate-ca"
}

variable "certificate_template_name" {
  type        = string
  description = "Name of the Certificate Template to create for a private_cert secret engine. When var.existing_sm_instance_guid is true, then it has to be the existing template name that exists in the private cert engine."
  default     = "my-template"
}

variable "create_policy" {
  description = "Set to true to create a new access group (using the value of var.access_group_name) with a VPN Client role"
  type        = bool
  default     = true
}

variable "vpn_client_access_group_users" {
  description = "List of users in the Client to Site VPN Access Group"
  type        = list(string)
  default     = []
}

variable "access_group_name" {
  type        = string
  description = "Name of the IAM Access Group to create if var.create_policy is true"
  default     = "client-to-site-vpn-access-group"
}

variable "vpn_server_routes" {
  type = map(object({
    destination = string
    action      = string
  }))
  description = "Map of server routes to be added to created VPN server."
  # Disabling VPN Server Route creation as there is a bug while destroying them using Terraform. Issue tracked here: https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4585
  default = {
    #    "vpc-192" = {
    #      destination = "192.168.0.0/22"
    #      action      = "deliver"
    #    }
  }
}
variable "root_ca_max_ttl" {
  type        = string
  description = "Maximum TTL value for the root CA"
  default     = "8760h"
}

variable "root_ca_common_name" {
  type        = string
  description = "Fully qualified domain name or host domain name for the certificate to be created"
  default     = "cloud.ibm.com"
}
