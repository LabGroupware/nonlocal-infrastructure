########################################
# Provider to connect to AWS
#
# https://www.terraform.io/docs/providers/aws/
########################################

terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70.0"
    }
  }

  backend "s3" {
    bucket  = "s3-apne1-lg-terraform-remote-backend-state-management"
    region  = "ap-northeast-1"
    key     = "lg-event-infra/ap-northeast-1/prod/terraform.tfstate"
    dynamodb_table = "dynamo-apne1-lg-terraform-remote-backend-state-management-lock"
    encrypt = true
  }
}
