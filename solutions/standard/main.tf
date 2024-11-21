#######################################################################################################################
# Resource Group
#######################################################################################################################
module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.1.6"
  resource_group_name          = var.use_existing_resource_group == false ? (var.prefix != null ? "${var.prefix}-${var.resource_group_name}" : var.resource_group_name) : null
  existing_resource_group_name = var.use_existing_resource_group == true ? var.resource_group_name : null
}

########################################################################################################################
# Secrets Manager resources
########################################################################################################################
locals {
  secrets_manager_cert_crn        = var.existing_secrets_manager_cert_crn != null ? var.existing_secrets_manager_cert_crn : module.secrets_manager_private_certificate[0].secret_crn
  secrets_manager_secret_group_id = var.existing_secrets_manager_cert_crn != null ? null : var.existing_secrets_manager_secret_group_id != null ? var.existing_secrets_manager_secret_group_id : module.secrets_manager_secret_group[0].secret_group_id

  # tflint-ignore: terraform_unused_declarations
  validate_encryption_inputs = var.existing_secrets_manager_cert_crn == null && (var.cert_common_name == null || var.certificate_template_name == null) ? tobool("Set cert_common_name and certificate_template_name input variables if a 'existing_secrets_manager_cert_crn' input variable is not set") : true
}
module "existing_sm_crn_parser" {
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.0.0"
  crn     = var.existing_secrets_manager_instance_crn
}

module "existing_secrets_manager_cert_crn_parser" {
  count   = var.existing_secrets_manager_cert_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.0.0"
  crn     = var.existing_secrets_manager_cert_crn
}

# Create a secret group to place the certificate if provisioning a new certificate
module "secrets_manager_secret_group" {
  count                    = var.existing_secrets_manager_cert_crn == null && var.existing_secrets_manager_secret_group_id == null ? 1 : 0
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.2.2"
  region                   = module.existing_sm_crn_parser.region
  secrets_manager_guid     = module.existing_sm_crn_parser.service_instance
  secret_group_name        = var.prefix != null ? "${var.prefix}-cert-secret-group" : "cert-secret-group"
  secret_group_description = "secret group used for private certificates"
  providers = {
    ibm = ibm.ibm-sm
  }
}

# Create private certificate to use for VPN server
module "secrets_manager_private_certificate" {
  count                  = var.existing_secrets_manager_cert_crn == null ? 1 : 0
  source                 = "terraform-ibm-modules/secrets-manager-private-cert/ibm"
  version                = "1.3.1"
  cert_name              = var.prefix != null ? "${var.prefix}-cts-vpn-private-cert" : "cts-vpn-private-cert"
  cert_description       = "private certificate for client to site VPN connection"
  cert_template          = var.certificate_template_name
  cert_secrets_group_id  = local.secrets_manager_secret_group_id
  cert_common_name       = var.cert_common_name
  secrets_manager_guid   = module.existing_sm_crn_parser.service_instance
  secrets_manager_region = module.existing_sm_crn_parser.region
  providers = {
    ibm = ibm.ibm-sm
  }
}

##############################################################################
# Deploy client-to-site in a dedicated subnets in the VPC
##############################################################################
locals {
  existing_vpc_id = module.existing_vpc_crn_parser.resource
  subnet_ids      = [ibm_is_subnet.client_to_site_subnet_zone_1.id, ibm_is_subnet.client_to_site_subnet_zone_2.id]
  zone_1          = var.vpn_zone_1 != null ? var.vpn_zone_1 : "${var.region}-1" # hardcode to first zone in region
  zone_2          = var.vpn_zone_2 != null ? var.vpn_zone_2 : "${var.region}-2" # hardcode to secod zone in region
  target_ids      = [module.vpn.vpn_server_id]
  acl_object = {
    for network_acl in var.network_acls :
    network_acl.name => {
      name  = network_acl.name
      rules = network_acl.rules,
    }
  }
}

module "existing_vpc_crn_parser" {
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.0.0"
  crn     = var.existing_vpc_crn
}

resource "ibm_is_vpc_address_prefix" "client_to_site_address_prefixes_zone_1" {
  name = var.prefix != null ? "${var.prefix}-client-to-site-address-prefixes-1" : "client-to-site-address-prefixes-1"
  zone = local.zone_1
  vpc  = local.existing_vpc_id
  cidr = var.vpn_subnet_cidr_zone_1
}

resource "ibm_is_vpc_address_prefix" "client_to_site_address_prefixes_zone_2" {
  name = var.prefix != null ? "${var.prefix}-client-to-site-address-prefixes-2" : "client-to-site-address-prefixes-2"
  zone = local.zone_2
  vpc  = local.existing_vpc_id
  cidr = var.vpn_subnet_cidr_zone_2
}

resource "ibm_is_network_acl" "client_to_site_vpn_acl" {
  for_each = local.acl_object
  name     = each.key
  vpc      = local.existing_vpc_id

  # Create ACL rules
  dynamic "rules" {
    for_each = each.value.rules
    content {
      name        = rules.value.name
      action      = rules.value.action
      source      = rules.value.source
      destination = rules.value.destination
      direction   = rules.value.direction

      dynamic "tcp" {
        for_each = (
          # if rules null
          rules.value.tcp == null
          # empty array
          ? []
          # otherwise check each possible field against how many of the values are
          # equal to null and only include rules where one of the values is not null
          # this allows for patterns to include `tcp` blocks for conversion to list
          # while still not creating a rule. default behavior would force the rule to
          # be included if all indiviual values are set to null
          : length([
            for value in ["port_min", "port_max", "source_port_min", "source_port_min"] :
            true if lookup(rules.value["tcp"], value, null) == null
          ]) == 4
          ? []
          : [rules.value]
        )
        content {
          port_min        = lookup(rules.value.tcp, "port_min", null)
          port_max        = lookup(rules.value.tcp, "port_max", null)
          source_port_min = lookup(rules.value.tcp, "source_port_min", null)
          source_port_max = lookup(rules.value.tcp, "source_port_max", null)
        }
      }

      dynamic "udp" {
        for_each = (
          # if rules null
          rules.value.udp == null
          # empty array
          ? []
          # otherwise check each possible field against how many of the values are
          # equal to null and only include rules where one of the values is not null
          # this allows for patterns to include `udp` blocks for conversion to list
          # while still not creating a rule. default behavior would force the rule to
          # be included if all indiviual values are set to null
          : length([
            for value in ["port_min", "port_max", "source_port_min", "source_port_min"] :
            true if lookup(rules.value["udp"], value, null) == null
          ]) == 4
          ? []
          : [rules.value]
        )
        content {
          port_min        = lookup(rules.value.udp, "port_min", null)
          port_max        = lookup(rules.value.udp, "port_max", null)
          source_port_min = lookup(rules.value.udp, "source_port_min", null)
          source_port_max = lookup(rules.value.udp, "source_port_max", null)
        }
      }

      dynamic "icmp" {
        for_each = (
          # if rules null
          rules.value.icmp == null
          # empty array
          ? []
          # otherwise check each possible field against how many of the values are
          # equal to null and only include rules where one of the values is not null
          # this allows for patterns to include `udp` blocks for conversion to list
          # while still not creating a rule. default behavior would force the rule to
          # be included if all indiviual values are set to null
          : length([
            for value in ["code", "type"] :
            true if lookup(rules.value["icmp"], value, null) == null
          ]) == 2
          ? []
          : [rules.value]
        )
        content {
          type = rules.value.icmp.type
          code = rules.value.icmp.code
        }
      }
    }
  }
}

# input: restrict to the clients IPS () - required - maybe in descriptio u can cfeate 0.0.0 to use as it oepn

resource "ibm_is_subnet" "client_to_site_subnet_zone_1" {
  depends_on      = [ibm_is_vpc_address_prefix.client_to_site_address_prefixes_zone_1]
  name            = var.prefix != null ? "${var.prefix}-client-to-site-subnet-1" : "client-to-site-subnet-1"
  vpc             = local.existing_vpc_id
  ipv4_cidr_block = var.vpn_subnet_cidr_zone_1
  zone            = local.zone_1
  network_acl     = ibm_is_network_acl.client_to_site_vpn_acl[keys(local.acl_object)[0]].id
}

resource "ibm_is_subnet" "client_to_site_subnet_zone_2" {
  depends_on      = [ibm_is_vpc_address_prefix.client_to_site_address_prefixes_zone_2]
  name            = var.prefix != null ? "${var.prefix}-client-to-site-subnet-2" : "client-to-site-subnet-2"
  vpc             = local.existing_vpc_id
  ipv4_cidr_block = var.vpn_subnet_cidr_zone_2
  zone            = local.zone_2
  network_acl     = ibm_is_network_acl.client_to_site_vpn_acl[keys(local.acl_object)[0]].id
}

module "vpn" {
  source                        = "../.."
  depends_on                    = [time_sleep.wait_for_security_group]
  server_cert_crn               = local.secrets_manager_cert_crn
  vpn_gateway_name              = var.prefix != null ? "${var.prefix}-${var.name}" : var.name
  resource_group_id             = module.resource_group.resource_group_id
  subnet_ids                    = local.subnet_ids
  create_policy                 = var.create_policy
  vpn_client_access_group_users = var.vpn_client_access_group_users
  access_group_name             = var.prefix != null ? "${var.prefix}-${var.access_group_name}" : var.access_group_name
  secrets_manager_id            = module.existing_sm_crn_parser.service_instance
  vpn_server_routes             = var.vpn_server_routes
}

# workaround for https://github.com/terraform-ibm-modules/terraform-ibm-client-to-site-vpn/issues/45
resource "time_sleep" "wait_for_security_group" {
  depends_on       = [module.client_to_site_sg.ibm_is_security_group]
  create_duration  = "10s"
  destroy_duration = "60s"
}

module "client_to_site_sg" {
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.2"
  add_ibm_cloud_internal_rules = true
  vpc_id                       = local.existing_vpc_id
  resource_group               = module.resource_group.resource_group_id
  security_group_name          = var.prefix != null ? "${var.prefix}-client-to-site-sg" : "client-to-site-sg"
  security_group_rules         = var.security_group_rules
}

# we add security group target after VPN and client_to_site_sg are created. Otherwise cycle dependency error is thrown
resource "ibm_is_security_group_target" "sg_target" {
  count          = length([module.vpn.vpn_server_id])
  security_group = module.client_to_site_sg.security_group_id
  target         = local.target_ids[count.index]
}
