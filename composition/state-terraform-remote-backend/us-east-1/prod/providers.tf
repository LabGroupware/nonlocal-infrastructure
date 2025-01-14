########################################
# Provider to connect to AWS
#
# https://www.terraform.io/docs/providers/aws/
########################################

provider "aws" {
  region  = var.region
  profile = var.profile_name
}

terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70.0"
    }
  }

  backend "s3" {
    bucket  = "s3-use1-lg-terraform-remote-backend-state-management"
    region  = "us-east-1"
    key     = "lg-state-infra/us-east-1/prod/terraform.tfstate"
    dynamodb_table = "dynamo-use1-lg-terraform-remote-backend-state-management-lock"
    encrypt = true
  }
}
