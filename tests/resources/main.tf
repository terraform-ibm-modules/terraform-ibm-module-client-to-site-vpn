##############################################################################
# Resource Group
##############################################################################

module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.0.5"
  existing_resource_group_name = var.resource_group
}

##############################################################################
# COS instance and bucket
##############################################################################

module "cos" {
  source                 = "git::https://github.com/terraform-ibm-modules/terraform-ibm-cos?ref=v6.10.0"
  resource_group_id      = module.resource_group.resource_group_id
  cos_instance_name      = "${var.prefix}-cos"
  create_cos_bucket      = true
  kms_encryption_enabled = false
  region                 = var.region
  cos_tags               = var.resource_tags
  bucket_name            = var.prefix
}
