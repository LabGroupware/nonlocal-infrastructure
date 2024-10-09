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

    external = {
      source  = "hashicorp/external"
      version = "2.3.4"
    }
  }
}
