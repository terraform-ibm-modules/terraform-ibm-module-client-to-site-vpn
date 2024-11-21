# Client-To-Site VPN solution

The solution creates and configures the following infrastructure:

1) When `existing_secrets_manager_secret_group_id` input variable is not passed:
    - creates a secrets manager secret group

2) When `existing_secrets_manager_cert_crn` input variable is not passed:
    - creates a private certificate (the "secret") from the private certificate engine in the secret group

3) Creates `client-to-site-subnet-1` and `client-to-site-subnet-2` subnets in the existing VPC

4) Creates `client-to-site-sg` security group. Allowed incoming requests are defined with `security_group_rules` input variable.

5) The network ACL on these subnets grants the access according to the `network_acls` input variable

6) Creates a client-to-site VPN gateway
    - uses the private certificate that is generated and stored in the Secrets Manager instance
    - locates the gateway in the `client-to-site-subnet-1` and `client-to-site-subnet-2` subnets
    - attaches the `client-to-site-sg` security group to the client-to-site VPN gateway
    - configures routes to allow access to the landing zone VPC
