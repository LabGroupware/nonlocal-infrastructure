## S3 ##
output "s3_terraform-remote-backend_id" {
  description = "The name of the table"
  value       = module.terraform-remote-backend.s3_id
}

output "s3_terraform-remote-backend_arn" {
  description = "The arn of the table"
  value       = module.terraform-remote-backend.s3_arn
}

## DynamoDB ##
output "dynamodb_terraform_state_lock_id" {
  description = "The name of the table"
  value       = module.terraform-remote-backend.dynamodb_id
}

output "dynamodb_terraform_state_lock_arn" {
  description = "The arn of the table"
  value       = module.terraform-remote-backend.dynamodb_arn
}

## KMS key ##
output "s3_kms_terraform_backend_arn" {
  description = "The Amazon Resource Name (ARN) of the key."
  value       = module.terraform-remote-backend.s3_kms_arn
}

output "s3_kms_terraform_backend_id" {
  description = "The globally unique identifier for the key."
  value       = module.terraform-remote-backend.s3_kms_id
}
