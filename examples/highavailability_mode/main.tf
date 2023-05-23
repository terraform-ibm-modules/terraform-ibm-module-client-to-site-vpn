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

# Best practise, use the secrets manager secret group module to create a secret group
module "secrets_manager_secret_group" {
  source                   = "git::https://github.ibm.com/GoldenEye/secrets-manager-secret-group-module.git?ref=2.0.1"
  region                   = local.sm_region
  secrets_manager_guid     = local.sm_guid
  secret_group_name        = "${var.prefix}-certificates-secret-group"    #checkov:skip=CKV_SECRET_6: does not require high entropy string as is static value
  secret_group_description = "secret group used for private certificates" #tfsec:ignore:general-secrets-no-plaintext-exposure
}

module "private_secret_engine" {
  depends_on                = [ibm_resource_instance.secrets_manager]
  count                     = var.existing_sm_instance_guid == null ? 1 : 0
  source                    = "git::https://github.ibm.com/GoldenEye/secrets-manager-private-cert-engine-module.git?ref=2.1.0"
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
  source                 = "git::https://github.ibm.com/GoldenEye/secrets-manager-private-cert-module.git?ref=2.0.0"
  cert_name              = "${var.prefix}-cts-vpn-private-cert"
  cert_description       = "an example private cert"
  cert_template          = var.certificate_template_name
  cert_secrets_group_id  = module.secrets_manager_secret_group.secret_group_id
  cert_common_name       = "goldeneye.appdomain.cloud"
  secrets_manager_guid   = local.sm_guid
  secrets_manager_region = local.sm_region
}

# ---------------------------------------------------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------------------------------------------------

module "acl_profile" {
  source = "git::https://github.ibm.com/GoldenEye/acl-profile-ocp.git?ref=1.1.2"
}

locals {
  acl_rules_map = {
    private = concat(
      module.acl_profile.base_acl,
      module.acl_profile.https_acl,
      module.acl_profile.deny_all_acl
    )
  }
}

module "vpc" {
  source                    = "git::https://github.ibm.com/GoldenEye/vpc-module.git?ref=5.4.0"
  unique_name               = var.prefix
  ibm_region                = local.sm_region
  resource_group_id         = module.resource_group.resource_group_id
  use_mgmt_subnet           = true
  acl_rules_map             = local.acl_rules_map
  virtual_private_endpoints = {}
  vpc_tags                  = var.resource_tags
}

module "vpn" {
  depends_on        = [module.vpc]
  source            = "../.."
  server_cert_crn   = module.secrets_manager_private_certificate.secret_crn
  vpn_gateway_name  = local.vpn_gateway_name
  resource_group_id = module.resource_group.resource_group_id
  # If "module.vpc.subnets["mgmt"]" list has >= 2 values then slice the list to get the first 2 values.
  subnet_ids                    = length(module.vpc.subnets["mgmt"]) >= 2 ? slice([for k in module.vpc.subnets["mgmt"] : k["id"]], 0, 2) : [for k in module.vpc.subnets["mgmt"] : k["id"]]
  create_policy                 = var.create_policy
  vpn_client_access_group_users = var.vpn_client_access_group_users
  access_group_name             = "${var.prefix}-${var.access_group_name}"
  secrets_manager_id            = local.sm_guid
  vpn_server_routes             = var.vpn_server_routes
}
