# Client-To-Site VPN solution

The solution creates and configures the following infrastructure:

1) When `existing_secrets_manager_cert_crn` is not passed:
  - creates a secret group
  - creates a private certificate engine
  - creates a private certificate (the "secret") from the private certificate engine in the secret group

2) When `existing_subnet_names` is not passed:
  - creates `client-to-site-subnet-1` and `client-to-site-subnet-2` subnets in the existing VPC
  - the network ACL on these subnets grants all access from any source

3) Creates a client-to-site VPN gateway
  - uses the private certificate that is generated and stored in the Secrets Manager instance
  - attaches the client-to-site-sg to the client-to-site VPN gateway

4) When `adjust_existing_subnet_name` is passed:
  - updates the existing acl rules to allow inbound/outbound traffic to the VPN client ips
