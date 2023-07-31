##############################################################################
# Account variables
##############################################################################

variable "resource_group_id" {
  description = "ID of the resource group to use when creating the VPN server"
  type        = string
}

##############################################################################
# VPN server variables
##############################################################################

variable "vpn_gateway_name" {
  type        = string
  description = "The user-defined name for the VPN server. If unspecified, the name will be a hyphenated list of randomly-selected words. Names must be unique within the VPC the VPN server is serving."
}

variable "client_ip_pool" {
  type        = string
  description = "The VPN client IPv4 address pool, expressed in CIDR format. The request must not overlap with any existing address prefixes in the VPC or any of the following reserved address ranges: - 127.0.0.0/8 (IPv4 loopback addresses) - 161.26.0.0/16 (IBM services) - 166.8.0.0/14 (Cloud Service Endpoints) - 169.254.0.0/16 (IPv4 link-local addresses) - 224.0.0.0/4 (IPv4 multicast addresses). The prefix length of the client IP address pool's CIDR must be between /9 (8,388,608 addresses) and /22 (1024 addresses). A CIDR block that contains twice the number of IP addresses that are required to enable the maximum number of concurrent connections is recommended."
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

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs to provision this VPN server in. List must have at least 1 subnet ID for standalone VPN and at least 2 subnet IDs for the High Availability mode."
  validation {
    error_message = "The list should have at least 1 subnet ID and maximum of 2 subnet IDs"
    condition     = (length(var.subnet_ids) > 0 && length(var.subnet_ids) < 3)
  }
}

variable "server_cert_crn" {
  type        = string
  description = "CRN of a secret in Secrets Manager that contains the certificate to use for the VPN"
}

variable "enable_split_tunneling" {
  type        = bool
  description = "Enables split tunnel mode for the Client to Site VPN server"
  default     = true
}

##############################################################################
# Auth related variables
##############################################################################

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

##############################################################################
# VPN server route variables
##############################################################################

variable "vpn_server_routes" {
  type = map(object({
    destination = string
    action      = string
  }))
  description = "Map of server routes to be added to created VPN server."
  default     = {}
}
