# Client-To-Site VPN solution

The solution creates and configures the following infrastructure:

1) When `existing_secrets_manager_secret_group_id` input variable is not passed:
 - creates a secrets manager secret group

2) When `existing_secrets_manager_cert_crn` input variable is not passed:
  - creates a private certificate (the "secret") from the private certificate engine in the secret group

3) Creates `client-to-site-subnet-1` in the existing VPC

4) The network ACL on these subnets grants all access from any source

5) Creates a client-to-site VPN gateway
  - uses the private certificate that is generated and stored in the Secrets Manager instance
  - attaches the `client-to-site-sg` security group to the client-to-site VPN gateway
