##############################################################################
# Outputs
##############################################################################

output "resource_group_name" {
  description = "Resource group name"
  value       = module.resource_group.resource_group_name
}

output "resource_group_id" {
  description = "Resource group ID"
  value       = module.resource_group.resource_group_id
}

output "vpn_server_certificate_secret_id" {
  description = "ID of the client to site vpn server certificate secret stored in Secrets Manager"
  value       = var.existing_secrets_manager_cert_crn == null ? module.secrets_manager_private_certificate[0].secret_id : module.existing_secrets_manager_cert_crn_parser[0].service_instance
}

output "vpn_server_certificate_secret_crn" {
  description = "CRN of the client to site vpn server certificate secret stored in Secrets Manager"
  value       = local.secrets_manager_cert_crn
}

output "vpn_id" {
  description = "Client to Site VPN ID"
  value       = module.vpn.vpn_server_id
}
