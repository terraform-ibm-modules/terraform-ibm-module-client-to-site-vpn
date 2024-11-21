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

variable "existing_secrets_manager_secret_group_id" {
  type        = string
  description = "The CRN of existing secrets manager secret group id used for new created certificate. If the value is null, then new secrets manager secret group is created."
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

##############################################################################
# client-to-site VPN
##############################################################################

variable "vpn_subnet_cidr_zone_1" {
  type        = string
  description = "The CIDR range to use from the first zone in the region (or zone specified in the 'vpn_zone_1' input variable)"
  default     = "10.10.40.0/24"
}

variable "vpn_subnet_cidr_zone_2" {
  type        = string
  description = "The CIDR range to use from the second zone in the region (or zone specified in the 'vpn_zone_2' input variable)."
  default     = "10.10.80.0/24"
}

variable "network_acls" {
  description = "The list of ACLs to create. Provide at least one rule for each ACL."
  type = list(
    object({
      name = string
      rules = list(
        object({
          name        = string
          action      = string
          destination = string
          direction   = string
          source      = string
          tcp = optional(
            object({
              port_max        = optional(number)
              port_min        = optional(number)
              source_port_max = optional(number)
              source_port_min = optional(number)
            })
          )
          udp = optional(
            object({
              port_max        = optional(number)
              port_min        = optional(number)
              source_port_max = optional(number)
              source_port_min = optional(number)
            })
          )
          icmp = optional(
            object({
              type = optional(number)
              code = optional(number)
            })
          )
        })
      )
    })
  )

  validation {
    error_message = "ACL rule actions can only be `allow` or `deny`."
    condition = length(distinct(
      flatten([
        # Check through rules
        for rule in flatten([var.network_acls[*].rules]) :
        # Return false action is not valid
        false if !contains(["allow", "deny"], rule.action)
      ])
    )) == 0
  }

  validation {
    error_message = "ACL rule actions can only be `allow` or `deny`."
    condition = length(distinct(
      flatten([
        # Check through rules
        for rule in flatten([var.network_acls[*].rules]) :
        # Return false action is not valid
        false if !contains(["allow", "deny"], rule.action)
      ])
    )) == 0
  }

  validation {
    error_message = "ACL rule direction can only be `inbound` or `outbound`."
    condition = length(distinct(
      flatten([
        # Check through rules
        for rule in flatten([var.network_acls[*].rules]) :
        # Return false if direction is not valid
        false if !contains(["inbound", "outbound"], rule.direction)
      ])
    )) == 0
  }

  validation {
    error_message = "ACL rule names must match the regex pattern ^([a-z]|[a-z][-a-z0-9]*[a-z0-9])$."
    condition = length(distinct(
      flatten([
        # Check through rules
        for rule in flatten([var.network_acls[*].rules]) :
        # Return false if direction is not valid
        false if !can(regex("^([a-z]|[a-z][-a-z0-9]*[a-z0-9])$", rule.name))
      ])
    )) == 0
  }

}

variable "security_group_rules" {
  description = "A list of security group rules to be added to the default vpc security group"
  type = list(
    object({
      name      = string
      direction = optional(string, "inbound")
      remote    = string
      tcp = optional(
        object({
          port_max = optional(number)
          port_min = optional(number)
        })
      )
      udp = optional(
        object({
          port_max = optional(number)
          port_min = optional(number)
        })
      )
      icmp = optional(
        object({
          type = optional(number)
          code = optional(number)
        })
      )
    })
  )

  validation {
    error_message = "Security group rule direction can only be `inbound` or `outbound`."
    condition = (var.security_group_rules == null || length(var.security_group_rules) == 0) ? true : length(distinct(
      flatten([
        # Check through rules
        for rule in var.security_group_rules :
        # Return false if direction is not valid
        false if !contains(["inbound", "outbound"], rule.direction)
      ])
    )) == 0
  }

  validation {
    error_message = "Security group rule names must match the regex pattern ^([a-z]|[a-z][-a-z0-9_]*[a-z0-9])$."
    condition = (var.security_group_rules == null || length(var.security_group_rules) == 0) ? true : length(distinct(
      flatten([
        # Check through rules
        for rule in var.security_group_rules :
        # Return false if direction is not valid
        false if !can(regex("^([a-z]|[a-z][-a-z0-9_]*[a-z0-9])$", rule.name))
      ])
    )) == 0
  }

  validation {
    error_message = "Security group rules can only have one of `icmp`, `udp`, or `tcp`."
    condition = (var.security_group_rules == null || length(var.security_group_rules) == 0) ? true : length(distinct(
      # Get flat list of results
      flatten([
        # Check through rules
        for rule in var.security_group_rules :
        # Return true if there is more than one of `icmp`, `udp`, or `tcp`
        true if length(
          [
            for type in ["tcp", "udp", "icmp"] :
            true if rule[type] != null
          ]
        ) > 1
      ])
    )) == 0 # Checks for length. If all fields all correct, array will be empty
  }
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

variable "vpn_zone_2" {
  type        = string
  description = "Optionally specify the second zone where the VPN gateway will be created. If not specified, it will default to the second zone in the region but only if you have specified a value for the 'vpn_subnet_cidr_zone_2' input variable."
  default     = null
}

##############################################################################
# Provider
##############################################################################

variable "provider_visibility" {
  description = "Set the visibility value for the IBM terraform provider. Supported values are `public`, `private`, `public-and-private`. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/guides/custom-service-endpoints)."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private", "public-and-private"], var.provider_visibility)
    error_message = "Invalid visibility option. Allowed values are 'public', 'private', or 'public-and-private'."
  }
}
