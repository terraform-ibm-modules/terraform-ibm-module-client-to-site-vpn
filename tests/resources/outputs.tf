##############################################################################
# Outputs
##############################################################################

output "prefix" {
  value       = module.landing_zone.prefix
  description = "prefix"
}

output "management_vpc_crn" {
  value       = [for vpc in module.landing_zone.vpc_data : vpc if vpc.vpc_name == "${module.landing_zone.prefix}-management-vpc"][0].vpc_crn
  description = "CRN of management VPC"
}

output "resource_group_name" {
  value       = module.resource_group.resource_group_name
  description = "Resource group name"
}

output "sm_private_cert_crn" {
  value       = module.secrets_manager_private_certificate.secret_crn
  description = "CRN of secrets manager private certificate."
}
