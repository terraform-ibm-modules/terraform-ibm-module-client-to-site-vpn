# Basic example creating a standalone VPN server

Requirements:
- An existing Secrets Manager instance configured with the private cert engine
- A Certificate Template in the Secrets Manager instance to use for private cert creation.

This example will:
 - Create a new resource group if one is not passed in.
 - Create a new secret group in the Secrets Manager instance provided.
 - Create a new private cert and place it in a secret in the newly created secret group.
 - Create a new VPC in the resource group and region provided.
 - Create a standalone VPN server
