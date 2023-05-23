##############################################################################
# Outputs
##############################################################################

output "vpn_server_id" {
  description = "Client to Site VPN ID"
  value       = ibm_is_vpn_server.vpn.vpn_server
}

output "vpn_server_certificate_secret_crn" {
  description = "CRN of the client to site vpn server certificate secret stored in Secrets Manager"
  value       = var.server_cert_crn
}
