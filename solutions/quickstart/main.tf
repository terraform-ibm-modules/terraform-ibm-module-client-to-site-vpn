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
  secrets_manager_cert_crn        = module.secrets_manager_private_certificate.secret_crn
  secrets_manager_secret_group_id = module.secrets_manager_secret_group.secret_group_id
}

module "existing_sm_crn_parser" {
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.0.0"
  crn     = var.existing_secrets_manager_instance_crn
}

# Create a secret group to place the certificate if provisioning a new certificate
module "secrets_manager_secret_group" {
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
# Deploy client-to-site in a dedicated subnet in the VPC
##############################################################################
locals {
  existing_vpc_id = module.existing_vpc_crn_parser.resource
  subnet_ids      = [ibm_is_subnet.client_to_site_subnet_zone_1.id]
  zone_1          = "${var.region}-1" # hardcode to first zone in region
  target_ids      = [module.vpn.vpn_server_id]
  vpn_server_routes = {
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

resource "ibm_is_network_acl" "client_to_site_vpn_acl" {
  name = var.prefix != null ? "${var.prefix}-client-to-site-acl" : "client-to-site-acl"
  vpc  = local.existing_vpc_id
  rules {
    name        = "outbound"
    action      = "allow"
    source      = "0.0.0.0/0"
    destination = "0.0.0.0/0"
    direction   = "outbound"
    udp {
      source_port_min = 443
      source_port_max = 443
    }
  }
  rules {
    name        = "inbound"
    action      = "allow"
    source      = "0.0.0.0/0"
    destination = "0.0.0.0/0"
    direction   = "inbound"
    udp {
      port_min = 443
      port_max = 443
    }
  }
}

resource "ibm_is_subnet" "client_to_site_subnet_zone_1" {
  depends_on      = [ibm_is_vpc_address_prefix.client_to_site_address_prefixes_zone_1]
  name            = var.prefix != null ? "${var.prefix}-client-to-site-subnet-1" : "client-to-site-subnet-1"
  vpc             = local.existing_vpc_id
  ipv4_cidr_block = var.vpn_subnet_cidr_zone_1
  zone            = local.zone_1
  network_acl     = ibm_is_network_acl.client_to_site_vpn_acl.id
}

module "vpn" {
  source                        = "../.."
  depends_on                    = [time_sleep.wait_for_security_group]
  server_cert_crn               = local.secrets_manager_cert_crn
  vpn_gateway_name              = var.prefix != null ? "${var.prefix}-${var.name}" : var.name
  resource_group_id             = module.resource_group.resource_group_id
  subnet_ids                    = local.subnet_ids
  create_policy                 = true
  vpn_client_access_group_users = var.vpn_client_access_group_users
  access_group_name             = var.prefix != null ? "${var.prefix}-client-to-site-vpn-access-group" : "client-to-site-vpn-access-group"
  secrets_manager_id            = module.existing_sm_crn_parser.service_instance
  vpn_server_routes             = local.vpn_server_routes
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
  security_group_rules = [{
    name      = "allow-all-inbound"
    direction = "inbound"
    remote    = "0.0.0.0/0"
  }]
}

# we add security group target after VPN and client_to_site_sg are created. Otherwise cycle dependency error is thrown
resource "ibm_is_security_group_target" "sg_target" {
  count          = length([module.vpn.vpn_server_id])
  security_group = module.client_to_site_sg.security_group_id
  target         = local.target_ids[count.index]
}
