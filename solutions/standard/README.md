# Standard client to site VPN solution

This solution supports provisioning and configuring the following infrastructure:

- A resource group, if one is not passed in.
- A secrets manager secret group, if one is not passed in.
- A private certificate, if one is not passed in.
- `client-to-site-subnet-1` and `client-to-site-subnet-2` subnets in the existing VPC, if `existing_subnet_ids` input variable is empty array.
- A network ACL on these subnets grants the access according to the `remote_cidr` input variable. By default the deny all inbound and outbound ACL rule is created.
- Security group that allows incoming requests from source defined with `remote_cidr` input variable. The `add_security_group` input variable must be set to `true`
- A client to site VPN gateway

![cts-standard-da](../../reference-architecture/reference-architectures/cts-standard-da.svg.svg)

**Important:** Because this solution contains a provider configuration and is not compatible with the `for_each`, `count`, and `depends_on` arguments, do not call this solution from one or more other modules. For more information about how resources are associated with provider configurations with multiple modules, see [Providers Within Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers).
