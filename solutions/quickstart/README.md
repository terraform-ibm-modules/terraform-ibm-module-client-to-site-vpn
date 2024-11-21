# Client-To-Site VPN solution

The solution creates and configures the following infrastructure:

1) When `existing_secrets_manager_secret_group_id` input variable is not passed:
    - creates a secrets manager secret group

2) When `existing_secrets_manager_cert_crn` input variable is not passed:
    - creates a private certificate (the "secret") from the private certificate engine in the secret group

3) Creates `client-to-site-subnet-1` in the existing VPC

4) Creates the `client-to-site-sg` security group that allows all incoming requests from any source.

5) The network ACL on `client-to-site-subnet-1` subnet grants all access from any source

6) Creates a client-to-site VPN gateway
    - uses the private certificate that is generated and stored in the Secrets Manager instance
    - locates the gateway in the `client-to-site-subnet-1` subnet
    - attaches the `client-to-site-sg` security group to the client-to-site VPN gateway
    - configures routes to allow access to the landing zone VPC
