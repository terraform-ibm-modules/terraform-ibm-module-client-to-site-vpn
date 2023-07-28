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

variable "secrets_manager_guid" {
  type        = string
  description = "Existing Secrets Manager GUID. The existing Secret Manager instance must have private certificate engine configured."
}

variable "secrets_manager_region" {
  type        = string
  description = "The region in which the Secrets Manager instance exists."
}

variable "certificate_template_name" {
  type        = string
  description = "Name of an existing Certificate Template in the Secrets Manager instance to use for private cert creation."
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

variable "vpn_server_routes" {
  type = map(object({
    destination = string
    action      = string
  }))
  description = "Map of server routes to be added to created VPN server."
  default = {
    "vpc-10" = {
      destination = "10.0.0.0/8"
      action      = "deliver"
    }
  }
}
