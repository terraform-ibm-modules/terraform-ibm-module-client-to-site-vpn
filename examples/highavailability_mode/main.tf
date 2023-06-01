locals {
  vpn_gateway_name = format("%s-%s", var.prefix, var.base_vpn_gateway_name)
  sm_guid          = var.existing_sm_instance_guid == null ? ibm_resource_instance.secrets_manager[0].guid : var.existing_sm_instance_guid
  sm_region        = var.existing_sm_instance_region == null ? var.region : var.existing_sm_instance_region
}

##############################################################################
# Resource Group
##############################################################################

module "resource_group" {
  source = "git::https://github.com/terraform-ibm-modules/terraform-ibm-resource-group.git?ref=v1.0.5"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

# ---------------------------------------------------------------------------------------------------------------------
# Secrets Manager Instance
# ---------------------------------------------------------------------------------------------------------------------

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
}

# # Best practice, use the secrets manager secret group module to create a secret group
resource "ibm_sm_secret_group" "secret_group" {
  name        = "${var.prefix}-certificates-secret-group"
  description = "secret group used for private certificates"
  region      = local.sm_region
  instance_id = local.sm_guid
}


module "private_secret_engine" {
  depends_on                = [ibm_resource_instance.secrets_manager]
  count                     = var.existing_sm_instance_guid == null ? 1 : 0
  source                    = "git::https://github.com/terraform-ibm-modules/terraform-ibm-secrets-manager-private-cert-engine?ref=v1.0.0"
  secrets_manager_guid      = local.sm_guid
  region                    = local.sm_region
  root_ca_name              = var.root_ca_name
  intermediate_ca_name      = var.intermediate_ca_name
  certificate_template_name = var.certificate_template_name
  root_ca_max_ttl           = var.root_ca_max_ttl
  root_ca_common_name       = var.root_ca_common_name

}

module "secrets_manager_private_certificate" {
  depends_on             = [module.private_secret_engine]
  source                 = "git::https://github.com/terraform-ibm-modules/terraform-ibm-secrets-manager-private-cert.git?ref=v1.0.0"
  cert_name              = "${var.prefix}-cts-vpn-private-cert"
  cert_description       = "an example private cert"
  cert_template          = var.certificate_template_name
  cert_secrets_group_id  = ibm_sm_secret_group.secret_group.secret_group_id
  cert_common_name       = "goldeneye.appdomain.cloud"
  secrets_manager_guid   = local.sm_guid
  secrets_manager_region = local.sm_region
}

# ---------------------------------------------------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------------------------------------------------

# Minimal VPC for illustation purpose: 2 subnets across 2 availability zones
module "basic_vpc" {
  source               = "git::https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vpc.git?ref=v7.2.0"
  resource_group_id    = module.resource_group.resource_group_id
  region               = var.region
  name                 = "vpc"
  prefix               = var.prefix
  tags                 = var.resource_tags
  enable_vpc_flow_logs = false
  subnets = {
    zone-1 = [
      {
        name           = "subnet-a"
        cidr           = "10.10.10.0/24"
        public_gateway = true
        acl_name       = "vpc-acl"
      }
    ],
    zone-2 = [
      {
        name           = "subnet-b"
        cidr           = "10.20.10.0/24"
        public_gateway = true
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

module "vpn" {
  source                        = "../.."
  server_cert_crn               = module.secrets_manager_private_certificate.secret_crn
  vpn_gateway_name              = local.vpn_gateway_name
  resource_group_id             = module.resource_group.resource_group_id
  subnet_ids                    = slice([for subnet in data.ibm_is_vpc.basic_vpc.subnets : subnet["id"]], 0, 2)
  create_policy                 = var.create_policy
  vpn_client_access_group_users = var.vpn_client_access_group_users
  access_group_name             = "${var.prefix}-${var.access_group_name}"
  secrets_manager_id            = local.sm_guid
  vpn_server_routes             = var.vpn_server_routes
}
