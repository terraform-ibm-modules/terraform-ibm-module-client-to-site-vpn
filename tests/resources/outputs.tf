##############################################################################
# Outputs
##############################################################################

output "s3_endpoint_public" {
  value       = module.cos.s3_endpoint_public
  description = "S3 public endpoint"
}

output "cos_instance_id" {
  value       = module.cos.cos_instance_id
  description = "COS instance ID"
}

output "bucket_name" {
  value       = module.cos.bucket_name
  description = "Bucket name"
}

output "resource_group_name" {
  value       = module.resource_group.resource_group_name
  description = "Resource Group Name"
}
