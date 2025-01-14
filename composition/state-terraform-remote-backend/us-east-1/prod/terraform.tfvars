########################################
# Environment setting
########################################
region           = "us-east-1"
role_name        = "Admin"
profile_name     = "terraform"
env              = "prod"
application_name = "lg-state"
app_name         = "lg-state"

########################################
## Terraform State S3 Bucket
########################################
force_destroy      = false
versioning_enabled = true

## s3 bucket public access block ##
block_public_policy     = true
block_public_acls       = true
ignore_public_acls      = true
restrict_public_buckets = true

########################################
## DynamoDB
########################################
read_capacity  = 2
write_capacity = 2
billing_mode   = "PROVISIONED"
table_class    = "STANDARD"
hash_key       = "LockID"
sse_enabled    = true # enable server side encryption
attribute_name = "LockID"
attribute_type = "S"
