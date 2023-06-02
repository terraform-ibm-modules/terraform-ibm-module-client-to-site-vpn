locals {
  # There is a provider bug generating "module-metadata.json" where variable value is not access directly.
  # https://github.com/IBM-Cloud/terraform-config-inspect/issues/19
  subnet_ids = var.subnet_ids

  secrets_manager_validate_condition = (var.create_s2s_auth_policy == true && var.secrets_manager_id == null)
  secrets_manager_validate_msg       = "Value for 'secrets_manager_id' must not be null if 'create_s2s_auth_policy' is true"
  # tflint-ignore: terraform_unused_declarations
  secrets_manager_validate_check = regex("^${local.secrets_manager_validate_msg}$", (!local.secrets_manager_validate_condition ? local.secrets_manager_validate_msg : ""))
}

# IAM Service to Service Authorization
# More info: https://cloud.ibm.com/docs/vpc?topic=vpc-client-to-site-authentication#creating-iam-service-to-service
resource "ibm_iam_authorization_policy" "policy" {
  count                       = var.create_s2s_auth_policy ? 1 : 0
  source_service_name         = "is"
  source_resource_type        = "vpn-server"
  source_resource_group_id    = var.resource_group_id
  target_service_name         = "secrets-manager"
  target_resource_instance_id = var.secrets_manager_id
  roles                       = ["SecretsReader"]
}

# Access groups
# More info: https://cloud.ibm.com/docs/vpc?topic=vpc-create-iam-access-group
resource "ibm_iam_access_group" "cts_vpn_access_group" {
  count       = var.create_policy ? 1 : 0
  name        = var.access_group_name
  description = "Access group for the Client to Site VPN"
}

resource "ibm_iam_access_group_policy" "cts_vpn_access_group_policy" {
  count           = var.create_policy ? 1 : 0
  access_group_id = ibm_iam_access_group.cts_vpn_access_group[0].id
  roles           = ["VPN Client"]
  resources {
    service = "is"
  }
}

resource "ibm_iam_access_group_members" "cts_vpn_access_group_users" {
  count           = var.create_policy && length(var.vpn_client_access_group_users) > 0 ? 1 : 0
  access_group_id = ibm_iam_access_group.cts_vpn_access_group[0].id
  ibm_ids         = var.vpn_client_access_group_users
}

# Client to Site VPN
resource "ibm_is_vpn_server" "vpn" {
  certificate_crn = var.server_cert_crn
  client_authentication {
    method            = var.client_auth_methods
    identity_provider = var.client_auth_methods == "username" ? "iam" : null
  }
  client_idle_timeout    = var.client_idle_timeout
  client_ip_pool         = var.client_ip_pool
  client_dns_server_ips  = var.client_dns_server_ips
  enable_split_tunneling = var.enable_split_tunneling
  name                   = var.vpn_gateway_name
  subnets                = local.subnet_ids
  resource_group         = var.resource_group_id
}

resource "ibm_is_vpn_server_route" "server_route" {
  depends_on = [
    resource.ibm_iam_access_group.cts_vpn_access_group
  ]
  for_each    = var.vpn_server_routes
  vpn_server  = ibm_is_vpn_server.vpn.vpn_server
  destination = each.value.destination
  action      = each.value.action
  name        = each.key
}
