########################################################################################################################
# Resource Group
########################################################################################################################

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.1.6"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

########################################################################################################################
## Generate Private Cert using Secrets Manager
########################################################################################################################

# Create a secret group to place the certificate in
module "secrets_manager_group" {
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.2.2"
  region                   = var.secrets_manager_region
  secrets_manager_guid     = var.secrets_manager_guid
  secret_group_name        = "${var.prefix}-certs"
  secret_group_description = "A secret group to store private certs"
  providers = {
    ibm = ibm.ibm-sm
  }
}

# Create the private cert
module "secrets_manager_private_certificate" {
  source                 = "terraform-ibm-modules/secrets-manager-private-cert/ibm"
  version                = "1.3.2"
  cert_name              = "${var.prefix}-cts-vpn-private-cert"
  cert_description       = "an example private cert"
  cert_template          = var.certificate_template_name
  cert_secrets_group_id  = module.secrets_manager_group.secret_group_id
  cert_common_name       = "example.com"
  secrets_manager_guid   = var.secrets_manager_guid
  secrets_manager_region = var.secrets_manager_region
  providers = {
    ibm = ibm.ibm-sm
  }
}

########################################################################################################################
## VPC
########################################################################################################################

# Minimal VPC for illustration purpose: 1 subnet across 1 availability zone
module "basic_vpc" {
  source               = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version              = "7.19.1"
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
    zone-2 = []
    zone-3 = []
  }
}

data "ibm_is_vpc" "basic_vpc" {
  depends_on = [module.basic_vpc] # Explicit "depends_on" here to wait for the full subnet creations
  identifier = module.basic_vpc.vpc_id
}

########################################################################################################################
## VPN
########################################################################################################################

module "vpn" {
  source                        = "../.."
  server_cert_crn               = module.secrets_manager_private_certificate.secret_crn
  vpn_gateway_name              = "${var.prefix}-c2s-vpn"
  resource_group_id             = module.resource_group.resource_group_id
  subnet_ids                    = slice([for subnet in data.ibm_is_vpc.basic_vpc.subnets : subnet["id"]], 0, 1)
  create_policy                 = var.create_policy
  vpn_client_access_group_users = var.vpn_client_access_group_users
  access_group_name             = "${var.prefix}-access-group"
  secrets_manager_id            = var.secrets_manager_guid
  vpn_server_routes             = var.vpn_server_routes
}
