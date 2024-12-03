The terraform code in this directory is used by the tests to provision:
- landing zone VPC
- when `existing_secrets_manager_instance_crn` input variable is not passed:
    - Secrets manager group
    - Secrets manager private certificate
