# Complete example creating a high availability VPN server

An end-to-end example that creates the client to site VPN in high availability mode.

This example will:
- Create a new resource group if one is not passed in.
- Create a new Secrets Manager instance if one is not passed in and configure it with a private cert engine.
- Create a new secret group in the Secrets Manager instance.
- Create a new private cert and place it in a secret in the newly created secret group.
- Create a new VPC in the resource group and region provided.
- Create a high availability VPN server (spanning 2 subnets in different zones)
