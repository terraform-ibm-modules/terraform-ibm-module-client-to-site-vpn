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
  # tflint-ignore: terraform_unused_declarations
  validate_existing_subnet_ids_inputs = length(var.existing_subnet_ids) <= 0 && (var.vpn_subnet_cidr_zone_1 == null || var.vpn_subnet_cidr_zone_2 == null || var.remote_cidr == null) ? tobool("Set 'vpn_subnet_cidr_zone_1', 'vpn_subnet_cidr_zone_2' and 'remote_cidr input variables' if 'existing_subnet_ids' input variable is not set") : true

  vpc_region      = module.existing_vpc_crn_parser.region
  existing_vpc_id = module.existing_vpc_crn_parser.resource
  subnet_ids      = length(var.existing_subnet_ids) > 0 ? var.existing_subnet_ids : [ibm_is_subnet.client_to_site_subnet_zone_1[0].id, ibm_is_subnet.client_to_site_subnet_zone_2[0].id]
  zone_1          = var.vpn_zone_1 != null ? var.vpn_zone_1 : "${local.vpc_region}-1" # hardcode to first zone in region
  zone_2          = var.vpn_zone_2 != null ? var.vpn_zone_2 : "${local.vpc_region}-2" # hardcode to second zone in region
  target_ids      = [module.vpn.vpn_server_id]

  subnet_cidrs = [var.vpn_subnet_cidr_zone_1, var.vpn_subnet_cidr_zone_2, var.client_ip_pool]

  ##############################################################################
  # ACL rules
  ##############################################################################
  acl_outbound_rules_tcp = [
    for i, subnet_cidr in local.subnet_cidrs :
    {
      name        = "outbound-tcp-${i}"
      action      = "allow"
      source      = subnet_cidr
      destination = var.remote_cidr
      direction   = "outbound"
      udp         = null
      tcp = {
        port_min        = 1
        port_max        = 65535
        source_port_min = 1
        source_port_max = 65535
      }
    }
  ]
  acl_outbound_rules_udp = [
    for i, subnet_cidr in local.subnet_cidrs :
    {
      name        = "outbound-udp-${i}"
      action      = "allow"
      source      = subnet_cidr
      destination = var.remote_cidr
      direction   = "outbound"
      udp = {
        source_port_min = 443
        source_port_max = 443
      }
      tcp = null
    }
  ]
  acl_inbound_rules_tcp = [
    for i, subnet_cidr in local.subnet_cidrs :
    {
      name        = "inbound-tcp-${i}"
      action      = "allow"
      source      = var.remote_cidr
      destination = subnet_cidr
      direction   = "inbound"
      tcp = {
        port_min        = 1
        port_max        = 65535
        source_port_min = 1
        source_port_max = 65535
      }
      udp = null
    }
  ]
  acl_inbound_rules_udp = [
    for i, subnet_cidr in local.subnet_cidrs :
    {
      name        = "inbound-udp-${i}"
      action      = "allow"
      source      = var.remote_cidr
      destination = subnet_cidr
      direction   = "inbound"
      udp = {
        port_min = 443
        port_max = 443
      }
      tcp = null
    }
  ]
  acl_object = length(var.existing_subnet_ids) <= 0 ? {
    "vpn-network-acl-rule" = {
      rules = concat(local.acl_inbound_rules_tcp, local.acl_inbound_rules_udp, local.acl_outbound_rules_tcp, local.acl_outbound_rules_udp, local.deny_all_rules),
    }
  } : {}
  deny_all_rules = [
    {
      name        = "ibmflow-deny-all-inbound"
      action      = "deny"
      source      = "0.0.0.0/0"
      destination = "0.0.0.0/0"
      direction   = "inbound"
      tcp         = null
      udp         = null
      icmp        = null
    },
    {
      name        = "ibmflow-deny-all-outbound"
      action      = "deny"
      source      = "0.0.0.0/0"
      destination = "0.0.0.0/0"
      direction   = "outbound"
      tcp         = null
      udp         = null
      icmp        = null
    }
  ]
  ##############################################################################

  security_group_rule = [{
    name      = replace("allow-${var.remote_cidr}-inbound", "/\\.|\\//", "-")
    direction = "inbound"
    remote    = var.remote_cidr
    },
    {
      name      = replace("allow-${var.remote_cidr}-outbound", "/\\.|\\//", "-")
      direction = "outbound"
      remote    = var.remote_cidr
  }]

  vpn_server_routes = merge(
    {
      # Add route for PaaS IBM Cloud backbone. This is mostly used to give access to the Kube master endpoints.
      "vpc-166" = {
        destination = "166.8.0.0/14"
        action      = "deliver"
      },
      # Add route for IaaS IBM Cloud backbone.
      "vpc-161" = {
        destination = "161.26.0.0/16"
        action      = "deliver"
      }
    },
    {
      for i, r in var.vpn_server_routes : "vpc-${i}" => {
        "action"      = "deliver"
        "destination" = r
      }
    }
  )
}

module "existing_vpc_crn_parser" {
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.0.0"
  crn     = var.existing_vpc_crn
}

resource "ibm_is_vpc_address_prefix" "client_to_site_address_prefixes_zone_1" {
  count = length(var.existing_subnet_ids) > 0 ? 0 : 1
  name  = var.prefix != null ? "${var.prefix}-client-to-site-address-prefixes-1" : "client-to-site-address-prefixes-1"
  zone  = local.zone_1
  vpc   = local.existing_vpc_id
  cidr  = var.vpn_subnet_cidr_zone_1
}

resource "ibm_is_vpc_address_prefix" "client_to_site_address_prefixes_zone_2" {
  count = length(var.existing_subnet_ids) > 0 ? 0 : 1
  name  = var.prefix != null ? "${var.prefix}-client-to-site-address-prefixes-2" : "client-to-site-address-prefixes-2"
  zone  = local.zone_2
  vpc   = local.existing_vpc_id
  cidr  = var.vpn_subnet_cidr_zone_2
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

      dynamic "udp" {
        for_each = (rules.value.udp == null ? [] : length([for value in ["port_min", "port_max", "source_port_min", "source_port_max"] : true if lookup(rules.value["udp"], value, null) == null]) == 4 ? [] : [rules.value])
        content {
          port_min        = lookup(rules.value.udp, "port_min", null)
          port_max        = lookup(rules.value.udp, "port_max", null)
          source_port_min = lookup(rules.value.udp, "source_port_min", null)
          source_port_max = lookup(rules.value.udp, "source_port_max", null)
        }
      }
      dynamic "tcp" {
        for_each = (rules.value.tcp == null ? [] : length([for value in ["port_min", "port_max", "source_port_min", "source_port_max"] : true if lookup(rules.value["tcp"], value, null) == null]) == 4 ? [] : [rules.value])
        content {
          port_min        = lookup(rules.value.tcp, "port_min", null)
          port_max        = lookup(rules.value.tcp, "port_max", null)
          source_port_min = lookup(rules.value.tcp, "source_port_min", null)
          source_port_max = lookup(rules.value.tcp, "source_port_max", null)
        }
      }
    }
  }
}

resource "ibm_is_subnet" "client_to_site_subnet_zone_1" {
  count           = length(var.existing_subnet_ids) > 0 ? 0 : 1
  depends_on      = [ibm_is_vpc_address_prefix.client_to_site_address_prefixes_zone_1]
  name            = var.prefix != null ? "${var.prefix}-client-to-site-subnet-1" : "client-to-site-subnet-1"
  vpc             = local.existing_vpc_id
  ipv4_cidr_block = var.vpn_subnet_cidr_zone_1
  zone            = local.zone_1
  network_acl     = ibm_is_network_acl.client_to_site_vpn_acl[keys(local.acl_object)[0]].id
}

resource "ibm_is_subnet" "client_to_site_subnet_zone_2" {
  count           = length(var.existing_subnet_ids) > 0 ? 0 : 1
  depends_on      = [ibm_is_vpc_address_prefix.client_to_site_address_prefixes_zone_2]
  name            = var.prefix != null ? "${var.prefix}-client-to-site-subnet-2" : "client-to-site-subnet-2"
  vpc             = local.existing_vpc_id
  ipv4_cidr_block = var.vpn_subnet_cidr_zone_2
  zone            = local.zone_2
  network_acl     = ibm_is_network_acl.client_to_site_vpn_acl[keys(local.acl_object)[0]].id
}

##############################################################################
# we need to add the ACL rule to existing ACL to gain access from new client-to-site
# subnet to desired destination (in SLZ case to cluster dashboard)
##############################################################################

locals {
  existing_subnets_with_acls = flatten([
    for acl_rule in data.ibm_is_network_acl.existing_acls : [
      for subnet in acl_rule.subnets : {
        acl_rule = acl_rule.id
        subnet   = subnet
      }
    ]
  ])
}

data "ibm_is_network_acl" "existing_acls" {
  for_each    = toset(var.vpn_client_access_acl_ids)
  network_acl = each.value
}

data "ibm_is_subnet" "existing_subnets" {
  for_each   = { for i, v in local.existing_subnets_with_acls : i => v }
  identifier = each.value.subnet.id
}

resource "ibm_is_network_acl_rule" "outbound_acl_rules_subnet1" {
  for_each    = data.ibm_is_subnet.existing_subnets
  network_acl = each.value.network_acl
  before      = length(data.ibm_is_network_acl.existing_acls[each.value.network_acl].rules) > 0 && length([for r in data.ibm_is_network_acl.existing_acls[each.value.network_acl].rules : r if r.direction == "outbound"]) > 0 ? [for r in data.ibm_is_network_acl.existing_acls[each.value.network_acl].rules : r if r.direction == "outbound"][0].id : null
  name        = "outbound-cts-vpn-${each.key}"
  action      = "allow"
  source      = each.value.ipv4_cidr_block
  destination = var.client_ip_pool
  direction   = "outbound"
  # Need to ignore the before value (See https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4721#issuecomment-1658043342)
  lifecycle {
    ignore_changes = [before]
  }
}

resource "ibm_is_network_acl_rule" "inbound_acl_rules_subnet1" {
  for_each    = data.ibm_is_subnet.existing_subnets
  network_acl = each.value.network_acl
  before      = length(data.ibm_is_network_acl.existing_acls[each.value.network_acl].rules) > 0 && length([for r in data.ibm_is_network_acl.existing_acls[each.value.network_acl].rules : r if r.direction == "inbound"]) > 0 ? [for r in data.ibm_is_network_acl.existing_acls[each.value.network_acl].rules : r if r.direction == "inbound"][0].id : null
  name        = "inbound-cts-vpn-${each.key}"
  action      = "allow"
  source      = var.client_ip_pool
  destination = each.value.ipv4_cidr_block
  direction   = "inbound"
  # Need to ignore the before value (See https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4721#issuecomment-1658043342)
  lifecycle {
    ignore_changes = [before]
  }
}

##############################################################################

module "vpn" {
  source                        = "../.."
  depends_on                    = [time_sleep.wait_for_security_group]
  server_cert_crn               = local.secrets_manager_cert_crn
  vpn_gateway_name              = var.prefix != null ? "${var.prefix}-${var.vpn_name}" : var.vpn_name
  resource_group_id             = module.resource_group.resource_group_id
  subnet_ids                    = local.subnet_ids
  create_policy                 = var.create_policy
  vpn_client_access_group_users = var.vpn_client_access_group_users
  access_group_name             = var.prefix != null ? "${var.prefix}-${var.access_group_name}" : var.access_group_name
  secrets_manager_id            = module.existing_sm_crn_parser.service_instance
  vpn_server_routes             = local.vpn_server_routes
}

# workaround for https://github.com/terraform-ibm-modules/terraform-ibm-client-to-site-vpn/issues/45
resource "time_sleep" "wait_for_security_group" {
  count            = var.add_security_group ? 1 : 0
  depends_on       = [module.client_to_site_sg.ibm_is_security_group]
  create_duration  = "10s"
  destroy_duration = "60s"
}

module "client_to_site_sg" {
  count                        = var.add_security_group ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.2"
  add_ibm_cloud_internal_rules = true
  vpc_id                       = local.existing_vpc_id
  resource_group               = module.resource_group.resource_group_id
  security_group_name          = var.prefix != null ? "${var.prefix}-client-to-site-sg" : "client-to-site-sg"
  security_group_rules         = local.security_group_rule
}

# we add security group target after VPN and client_to_site_sg are created. Otherwise cycle dependency error is thrown
resource "ibm_is_security_group_target" "sg_target" {
  count          = var.add_security_group && length([module.vpn.vpn_server_id]) > 0 ? 1 : 0
  security_group = module.client_to_site_sg[0].security_group_id
  target         = local.target_ids[count.index]
}
