##############################################################################
# SLZ VPC
##############################################################################

module "landing_zone" {
  source                 = "terraform-ibm-modules/landing-zone/ibm//patterns//vpc//module"
  version                = "5.24.5"
  region                 = var.region
  prefix                 = var.prefix
  tags                   = var.resource_tags
  enable_transit_gateway = false
  add_atracker_route     = false
}
