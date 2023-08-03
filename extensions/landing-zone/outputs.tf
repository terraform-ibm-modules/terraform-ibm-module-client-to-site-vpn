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

output "server_cert_id" {
  description = "ID of the server cert stored in the Secrets Manager"
  value       = module.secrets_manager_private_certificate.secret_id
}

output "vpn_server_certificate_secret_crn" {
  description = "CRN of the client to site vpn server certificate secret stored in Secrets Manager"
  value       = module.secrets_manager_private_certificate.secret_crn
}

output "vpn_id" {
  description = "Client to Site VPN ID"
  value       = module.vpn.vpn_server_id
}
