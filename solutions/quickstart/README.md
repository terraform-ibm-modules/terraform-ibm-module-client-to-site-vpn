# Quickstart client to site VPN solution

This solution supports provisioning and configuring the following infrastructure:

- A resource group, if one is not passed in.
- A secrets manager secret group, if one is not passed in.
- A private certificate, if one is not passed in.
- `client-to-site-subnet-1` subnet in the existing VPC.
- A network ACL on `client-to-site-subnet-1` subnet grants all access from any source.
- Security group that allows all incoming requests from any source.
- A client to site VPN gateway

**Important:** Because this solution contains a provider configuration and is not compatible with the `for_each`, `count`, and `depends_on` arguments, do not call this solution from one or more other modules. For more information about how resources are associated with provider configurations with multiple modules, see [Providers Within Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers).
