terraform {
  backend "s3" {
    bucket         = "s3-use1-lg-state-prod-terraform-backend-ca444274"
    region         = "us-east-1"
    key            = "lg-state-infra/us-east-1/prod/terraform.tfstate"
    dynamodb_table = "dynamo-use1-lg-state-prod-terraform-state-lock"
    encrypt        = true
  }
}
