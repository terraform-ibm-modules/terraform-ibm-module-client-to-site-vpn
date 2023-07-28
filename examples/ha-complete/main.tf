########################################################################################################################
# Locals
########################################################################################################################

locals {
  sm_guid   = var.existing_sm_instance_guid == null ? ibm_resource_instance.secrets_manager[0].guid : var.existing_sm_instance_guid
  sm_region = var.existing_sm_instance_region == null ? var.region : var.existing_sm_instance_region
}

########################################################################################################################
# Resource Group
########################################################################################################################

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.0.6"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

########################################################################################################################
# Secrets Manager resources
########################################################################################################################

# Create a new SM instance if not using an existing one
resource "ibm_resource_instance" "secrets_manager" {
  count             = var.existing_sm_instance_guid == null ? 1 : 0
  name              = "${var.prefix}-sm-instance"
  service           = "secrets-manager"
  plan              = var.sm_service_plan
  location          = local.sm_region
  resource_group_id = module.resource_group.resource_group_id
  timeouts {
    create = "20m" # Extending provisioning time to 20 minutes
  }
  provider = ibm.ibm-sm
}

# Create a secret group to place the certificate in
module "secrets_manager_group" {
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.0.0"
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = "${var.prefix}-certs"
  secret_group_description = "A secret group to store private certs"
  providers = {
    ibm = ibm.ibm-sm
  }
}

# Configure private cert engine if provisioning a new SM instance
module "private_secret_engine" {
  depends_on                = [ibm_resource_instance.secrets_manager]
  count                     = var.existing_sm_instance_guid == null ? 1 : 0
  source                    = "terraform-ibm-modules/secrets-manager-private-cert-engine/ibm"
  version                   = "1.1.0"
  secrets_manager_guid      = local.sm_guid
  region                    = local.sm_region
  root_ca_name              = var.root_ca_name
  intermediate_ca_name      = var.intermediate_ca_name
  certificate_template_name = var.certificate_template_name
  root_ca_max_ttl           = var.root_ca_max_ttl
  root_ca_common_name       = var.root_ca_common_name
  providers = {
    ibm = ibm.ibm-sm
  }
}

# Create private cert to use for VPN server
module "secrets_manager_private_certificate" {
  depends_on             = [module.private_secret_engine]
  source                 = "terraform-ibm-modules/secrets-manager-private-cert/ibm"
  version                = "1.0.1"
  cert_name              = "${var.prefix}-cts-vpn-private-cert"
  cert_description       = "an example private cert"
  cert_template          = var.certificate_template_name
  cert_secrets_group_id  = module.secrets_manager_group.secret_group_id
  cert_common_name       = "example.com"
  secrets_manager_guid   = local.sm_guid
  secrets_manager_region = local.sm_region
  providers = {
    ibm = ibm.ibm-sm
  }
}

########################################################################################################################
# VPC
########################################################################################################################

# Minimal VPC for illustration purpose: 2 subnets across 2 availability zones
module "basic_vpc" {
  source               = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version              = "7.3.1"
  resource_group_id    = module.resource_group.resource_group_id
  region               = var.region
  name                 = "vpc"
  prefix               = var.prefix
  tags                 = var.resource_tags
  enable_vpc_flow_logs = false
  use_public_gateways = {
    zone-1 = false
    zone-2 = false
    zone-3 = false
  }
  subnets = {
    zone-1 = [
      {
        name           = "subnet-a"
        cidr           = "10.10.10.0/24"
        public_gateway = false
        acl_name       = "vpc-acl"
      }
    ],
    zone-2 = [
      {
        name           = "subnet-b"
        cidr           = "10.20.10.0/24"
        public_gateway = false
        acl_name       = "vpc-acl"
      }
    ],
    zone-3 = []
  }
}

data "ibm_is_vpc" "basic_vpc" {
  depends_on = [module.basic_vpc] # Explicit "depends_on" here to wait for the full subnet creations
  identifier = module.basic_vpc.vpc_id
}

########################################################################################################################
# VPN
########################################################################################################################

module "vpn" {
  source                        = "../.."
  server_cert_crn               = module.secrets_manager_private_certificate.secret_crn
  vpn_gateway_name              = "${var.prefix}-c2s-vpn"
  resource_group_id             = module.resource_group.resource_group_id
  subnet_ids                    = slice([for subnet in data.ibm_is_vpc.basic_vpc.subnets : subnet["id"]], 0, 2)
  create_policy                 = var.create_policy
  vpn_client_access_group_users = var.vpn_client_access_group_users
  access_group_name             = "${var.prefix}-${var.access_group_name}"
  secrets_manager_id            = local.sm_guid
  vpn_server_routes             = var.vpn_server_routes
}
