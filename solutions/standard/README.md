# Standard client to site VPN solution

This solution supports provisioning and configuring the following infrastructure:

- A resource group, if one is not passed in.
- A secrets manager secret group, if one is not passed in.
- A private certificate, if one is not passed in.
- `client-to-site-subnet-1` and `client-to-site-subnet-2` subnets in the existing VPC.
- A network ACL on these subnets grants the access according to the `network_acls` input variable.
- Security group that allows incoming requests from sources defined with `security_group_rules` input variable.
- A client to site VPN gateway

**Important:** Because this solution contains a provider configuration and is not compatible with the `for_each`, `count`, and `depends_on` arguments, do not call this solution from one or more other modules. For more information about how resources are associated with provider configurations with multiple modules, see [Providers Within Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers).
