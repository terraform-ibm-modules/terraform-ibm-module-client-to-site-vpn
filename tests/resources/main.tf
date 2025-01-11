##############################################################################
# SLZ VPC
##############################################################################

module "landing_zone" {
  source                 = "terraform-ibm-modules/landing-zone/ibm//patterns//vpc//module"
  version                = "6.6.3"
  region                 = var.region
  prefix                 = var.prefix
  tags                   = var.resource_tags
  enable_transit_gateway = false
  add_atracker_route     = false
}

################################################################################
# Resource Group
################################################################################
module "resource_group" {
  source              = "terraform-ibm-modules/resource-group/ibm"
  version             = "1.1.6"
  resource_group_name = "${var.prefix}-rg"
}

#################################################################################
# Secrets Manager resources
#################################################################################

locals {
  sm_region            = var.existing_secrets_manager_instance_crn != null ? module.existing_sm_crn_parser[0].region : null
  secrets_manager_guid = var.existing_secrets_manager_instance_crn != null ? module.existing_sm_crn_parser[0].service_instance : null
}

module "existing_sm_crn_parser" {
  count   = var.existing_secrets_manager_instance_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.1.0"
  crn     = var.existing_secrets_manager_instance_crn
}

# Create a secret group to place the certificate if provisioning a new certificate
module "secrets_manager_group" {
  count                    = var.existing_secrets_manager_instance_crn != null ? 1 : 0
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.2.2"
  region                   = local.sm_region
  secrets_manager_guid     = local.secrets_manager_guid
  secret_group_name        = "${var.prefix}-cert-secret-group"
  secret_group_description = "secret group used for private certificates"
  providers = {
    ibm = ibm.ibm-sm
  }
}

# Create private certificate to use for VPN server
module "secrets_manager_private_certificate" {
  count                  = var.existing_secrets_manager_instance_crn != null ? 1 : 0
  source                 = "terraform-ibm-modules/secrets-manager-private-cert/ibm"
  version                = "1.3.2"
  cert_name              = "${var.prefix}-cts-vpn-private-cert"
  cert_description       = "an example private cert"
  cert_template          = var.certificate_template_name
  cert_secrets_group_id  = module.secrets_manager_group[0].secret_group_id
  cert_common_name       = "${var.prefix}-example.com"
  secrets_manager_guid   = local.secrets_manager_guid
  secrets_manager_region = local.sm_region
  providers = {
    ibm = ibm.ibm-sm
  }
}
