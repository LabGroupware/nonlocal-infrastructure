## S3 ##
output "s3_id" {
  description = "The name of the table"
  value       = module.s3_bucket_terraform-remote-backend.s3_bucket_id
}

output "s3_arn" {
  description = "The arn of the table"
  value       = module.s3_bucket_terraform-remote-backend.s3_bucket_arn
}

## DynamoDB ##
output "dynamodb_id" {
  description = "The name of the table"
  value       = module.dynamodb_terraform_state_lock.dynamodb_table_id
}

output "dynamodb_arn" {
  description = "The arn of the table"
  value       = module.dynamodb_terraform_state_lock.dynamodb_table_arn
}

## KMS key ##
output "s3_kms_arn" {
  description = "The Amazon Resource Name (ARN) of the key."
  value       = module.s3_kms_key_terraform_backend.key_arn
}

output "s3_kms_alias_arn" {
  description = "The Amazon Resource Name (ARN) of the key alias."
  value       = module.s3_kms_key_terraform_backend.aliases
}

output "s3_kms_id" {
  description = "The globally unique identifier for the key."
  value       = module.s3_kms_key_terraform_backend.key_id
}
