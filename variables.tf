##############################################################################
# Account Variables
##############################################################################

variable "resource_group_id" {
  description = "ID of the resource group to use when creating the VPC"
  type        = string
}

variable "vpn_gateway_name" {
  type        = string
  description = "Name of the VPN"
  default     = "test"
}

variable "client_ip_pool" {
  type        = string
  description = "Client IP pool for the VPN"
  default     = "10.0.0.0/20"
}

variable "client_dns_server_ips" {
  type        = list(string)
  description = "DNS server addresses that will be provided to VPN clients connected to this VPN server"
  default     = []
}

variable "client_auth_methods" {
  type        = string
  description = "Client authentication method"
  default     = "username"
  validation {
    error_message = "Only authentication by username is supported."
    condition = can(contains(["username"], var.client_auth_methods)
    )
  }
}

variable "client_idle_timeout" {
  type        = number
  description = "The seconds a VPN client can be idle before this VPN server will disconnect it. Default set to 30m (1800 secs). Specify 0 to prevent the server from disconnecting idle clients."
  default     = 1800
}

##############################################################################
# VPC variables
##############################################################################

variable "subnet_ids" {
  type        = list(string)
  description = "List must have at least 1 subnet ID for standalone VPN and at least 2 subnet IDs for the High Availability mode."
  validation {
    error_message = "The list should have at least 1 subnet ID and maximum of 2 subnet IDs"
    condition     = (length(var.subnet_ids) > 0 && length(var.subnet_ids) < 3)
  }
}

##############################################################################
# Certificate variables
##############################################################################

variable "server_cert_crn" {
  type        = string
  description = "CRN of a secret in Secrets Manager that contains the certificate to use for the VPN"
}

##############################################################################
# VPN variables
##############################################################################

variable "enable_split_tunneling" {
  type        = bool
  description = "Enables split tunnel mode for the Client to Site VPN Creation"
  default     = true
}

variable "create_policy" {
  description = "Set to true to create a new access group (using the value of var.access_group_name) with a VPN Client role"
  type        = bool
  default     = true
}

variable "vpn_client_access_group_users" {
  description = "List of users to optionally add to the Client to Site VPN Access Group if var.create_policy is true"
  type        = list(string)
  default     = []
}

variable "access_group_name" {
  type        = string
  description = "Name of the IAM Access Group to create if var.create_policy is true"
  default     = "client-to-site-vpn-access-group"
}

variable "create_s2s_auth_policy" {
  type        = bool
  description = "Create IAM Service to Service Authorization to allow communication between all VPN Servers (scoped to the given resource group) and the given Secrets Manager instance. Currently not possible to scope the policy to the exact VPN server ID since the policy is needed before the instance exists as it uses the cert stored in secrets manager during the provisioning process."
  default     = true
}

variable "secrets_manager_id" {
  type        = string
  description = "ID of the Secrets Manager that contains the certificate to use for the VPN, only required when create_s2s_auth_policy is true."
  default     = null
}

variable "vpn_server_routes" {
  type = map(object({
    destination = string
    action      = string
  }))
  description = "Map of server routes to be added to created VPN server."
  default     = {}
}
