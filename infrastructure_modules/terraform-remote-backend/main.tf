# used to append random integer to S3 bucket to avoid conflicting bucket name across the globe
resource "random_bytes" "bytes" {
  length = 4

  keepers = {
    listener_arn = var.app_name
  }
}

module "s3_bucket_terraform-remote-backend" {
  source = "../../resource_modules/storage/s3"

  bucket        = local.bucket_name
  policy        = data.aws_iam_policy_document.bucket_policy.json
  tags          = local.tags
  force_destroy = var.force_destroy

  website                              = local.website
  cors_rule                            = local.cors_rule
  versioning                           = local.versioning
  logging                              = local.logging
  lifecycle_rule                       = local.lifecycle_rule
  replication_configuration            = local.replication_configuration
  server_side_encryption_configuration = local.server_side_encryption_configuration
  object_lock_configuration            = local.object_lock_configuration

  ## s3 bucket public access block ##
  block_public_policy     = var.block_public_policy
  block_public_acls       = var.block_public_acls
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

########################################
## Dynamodb for TF state locking
########################################
module "dynamodb_terraform_state_lock" {
  source         = "../../resource_modules/database/dynamodb"
  name           = local.dynamodb_name
  billing_mode   = var.billing_mode
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
  table_class    = var.table_class
  hash_key       = var.hash_key
  attributes = [{
    name = var.attribute_name
    type = var.attribute_type
  }]
  server_side_encryption_enabled = var.sse_enabled
  tags                           = var.tags
}

########################################
## KMS
########################################
module "s3_kms_key_terraform_backend" {
  source = "../../resource_modules/identity/kms"

  description             = local.ami_kms_key_description
  deletion_window_in_days = local.ami_kms_key_deletion_window_in_days
  tags                    = local.ami_kms_key_tags
  policy                  = data.aws_iam_policy_document.s3_terraform_states_kms_key_policy.json
  enable_key_rotation     = true
}
