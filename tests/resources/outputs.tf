##############################################################################
# Outputs
##############################################################################

output "prefix" {
  value       = module.landing_zone.prefix
  description = "The prefix appended to all resources that this solution created"
}

output "management_vpc_crn" {
  value       = [for vpc in module.landing_zone.vpc_data : vpc if vpc.vpc_name == "${module.landing_zone.prefix}-management-vpc"][0].vpc_crn
  description = "CRN of management VPC"
}

output "default_network_acl_id" {
  value       = [for vpc in module.landing_zone.vpc_data : vpc if vpc.vpc_name == "${module.landing_zone.prefix}-management-vpc"][0].vpc_data.default_network_acl
  description = "Default network ACL id"
}

output "resource_group_name" {
  value       = module.resource_group.resource_group_name
  description = "Resource group name"
}

output "sm_private_cert_crn" {
  value       = var.existing_secrets_manager_instance_crn != null ? module.secrets_manager_private_certificate[0].secret_crn : null
  description = "CRN of secrets manager private certificate"
}
