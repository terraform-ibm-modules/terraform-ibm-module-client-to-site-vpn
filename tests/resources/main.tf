##############################################################################
# SLZ VPC
##############################################################################

module "landing_zone" {
  source                 = "terraform-ibm-modules/landing-zone/ibm//patterns//vpc//module"
  version                = "6.0.0"
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

module "existing_sm_crn_parser" {
  # count   = var.existing_secrets_manager_instance_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.0.0"
  crn     = var.existing_secrets_manager_instance_crn
}

#################################################################################
# Secrets Manager resources
#################################################################################

# Create a secret group to place the certificate if provisioning a new certificate
module "secrets_manager_group" {
  source                   = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version                  = "1.2.2"
  region                   = module.existing_sm_crn_parser.region
  secrets_manager_guid     = module.existing_sm_crn_parser.service_instance
  secret_group_name        = "${var.prefix}-cert-secret-group"
  secret_group_description = "secret group used for private certificates"
  providers = {
    ibm = ibm.ibm-sm
  }
}

# Configure private cert engine if provisioning a new certificate
module "private_secret_engine" {
  source                    = "terraform-ibm-modules/secrets-manager-private-cert-engine/ibm"
  version                   = "1.3.2"
  secrets_manager_guid      = module.existing_sm_crn_parser.service_instance
  region                    = module.existing_sm_crn_parser.region
  root_ca_name              = "${var.prefix}-root-ca"
  root_ca_common_name       = "${var.prefix}-example.com"
  root_ca_max_ttl           = "8760h"
  intermediate_ca_name      = "${var.prefix}-intermediat-ca"
  certificate_template_name = "${var.prefix}-my-template"
  providers = {
    ibm = ibm.ibm-sm
  }
}

# Create private certificate to use for VPN server
module "secrets_manager_private_certificate" {
  depends_on             = [module.private_secret_engine]
  source                 = "terraform-ibm-modules/secrets-manager-private-cert/ibm"
  version                = "1.3.1"
  cert_name              = "${var.prefix}-cts-vpn-private-cert"
  cert_description       = "an example private cert"
  cert_template          = "geretain-cert-template"
  cert_secrets_group_id  = module.secrets_manager_group.secret_group_id
  cert_common_name       = "${var.prefix}-example.com"
  secrets_manager_guid   = module.existing_sm_crn_parser.service_instance
  secrets_manager_region = module.existing_sm_crn_parser.region
  providers = {
    ibm = ibm.ibm-sm
  }
}
